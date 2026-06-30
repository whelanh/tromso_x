#!/usr/bin/env python3
"""
Push a BuildStream OCI layout to a Docker Registry v2 (e.g., ghcr.io)
using the raw HTTP API. Avoids all container-tool manifest bugs.
"""
import base64, gzip, hashlib, json, os, shutil, sys, tempfile
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

REGISTRY = "ghcr.io"
REPO = "whelanh/tromso-kde-min"
TAG = "latest"
USER = "whelanh"
PASS = (Path.home() / "chessFiles" / "ghcr_token.txt").read_text().strip()

_bearer_token = None

def get_bearer_token():
    global _bearer_token
    if _bearer_token:
        return _bearer_token
    auth = base64.b64encode(f"{USER}:{PASS}".encode()).decode()
    url = f"https://{REGISTRY}/token?service={REGISTRY}&scope=repository:{REPO}:push,pull"
    r = Request(url, headers={"Authorization": f"Basic {auth}"})
    _bearer_token = json.loads(urlopen(r).read())["token"]
    return _bearer_token

def sha256_stream(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(8*1024*1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def req(method, url, data=None, headers=None, retry=True):
    h = {"Accept": "application/vnd.oci.image.manifest.v1+json,"
                   "application/vnd.docker.distribution.manifest.v2+json"}
    if headers:
        h.update(headers)
    h["Authorization"] = f"Bearer {get_bearer_token()}"
    r = Request(url, data=data, method=method, headers=h)
    try:
        return urlopen(r)
    except HTTPError as e:
        if e.code == 401 and retry:
            global _bearer_token
            _bearer_token = None
            return req(method, url, data, headers, retry=False)
        body = e.read().decode()
        print(f"HTTP {e.code} at {url[:80]}: {body[:200]}", file=sys.stderr)
        sys.exit(1)

def blob_exists(digest):
    try:
        req("HEAD", f"https://{REGISTRY}/v2/{REPO}/blobs/{digest}")
        return True
    except HTTPError as e:
        if e.code == 404:
            return False
        raise

def blob_upload_file(path, expected_digest_hex):
    """Upload a blob, streaming to avoid memory spikes."""
    digest = "sha256:" + expected_digest_hex
    if blob_exists(digest):
        print(f"  blob {digest[:16]}... already exists")
        return digest
    size = os.path.getsize(path)

    # Start upload session
    resp = req("POST", f"https://{REGISTRY}/v2/{REPO}/blobs/uploads/")
    loc = resp.headers["Location"]
    if loc.startswith("/"):
        loc = f"https://{REGISTRY}{loc}"
    sep = "&" if "?" in loc else "?"

    # Stream the file in the PUT request body.
    # We can't use urlopen with a fileobj directly, so we read in chunks
    # and construct the request. For large files, use a generator body.
    class FileReader:
        def __init__(self, path):
            self.f = open(path, "rb")
        def __iter__(self):
            return self
        def __next__(self):
            chunk = self.f.read(8*1024*1024)
            if not chunk:
                self.f.close()
                raise StopIteration
            return chunk
        def __len__(self):
            # Not accurate but prevents Transfer-Encoding: chunked in some cases
            return os.path.getsize(path)

    # Python's urllib doesn't support streaming PUT well.
    # Use subprocess + curl for the upload to avoid loading 3.6GB into RAM.
    import subprocess as sp
    put_url = f"{loc}{sep}digest={digest}"
    print(f"  uploading {digest[:16]}... ({size} bytes) via curl...")
    proc = sp.run([
        "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
        "-X", "PUT",
        "-H", f"Authorization: Bearer {get_bearer_token()}",
        "-H", "Content-Type: application/octet-stream",
        "--data-binary", f"@{path}",
        put_url
    ], capture_output=True, text=True)
    code = proc.stdout.strip()
    if code != "201":
        print(f"ERROR: upload failed with HTTP {code}: {proc.stderr[:200]}", file=sys.stderr)
        sys.exit(1)
    print(f"  uploaded {digest[:16]}... (HTTP {code})")
    return digest

def main():
    oci_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".build-out-kde")
    if not oci_dir.exists():
        print(f"Usage: {sys.argv[0]} [OCI_DIR]")
        sys.exit(1)

    # Read manifest
    index = json.loads((oci_dir / "index.json").read_text())
    mf_digest = index["manifests"][0]["digest"].replace("sha256:", "")
    manifest = json.loads((oci_dir / "blobs" / "sha256" / mf_digest).read_text())

    # Config blob
    cd = manifest["config"]["digest"].replace("sha256:", "")
    config_path = oci_dir / "blobs" / "sha256" / cd
    config_size = config_path.stat().st_size
    config_digest_hex = cd
    print(f"Config: {cd} ({config_size} bytes)")

    # Layer blob — compress with gzip
    ld = manifest["layers"][0]["digest"].replace("sha256:", "")
    layer_path = oci_dir / "blobs" / "sha256" / ld
    layer_raw_size = layer_path.stat().st_size
    print(f"Layer raw: {ld} ({layer_raw_size} bytes) — compressing...")

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".tar.gz")
    try:
        with open(layer_path, "rb") as fin, gzip.GzipFile(fileobj=tmp, mode="wb") as gz:
            shutil.copyfileobj(fin, gz)
        tmp.close()
        compressed_size = os.path.getsize(tmp.name)

        # Compute digest of compressed file
        compressed_digest_hex = sha256_stream(tmp.name)
        print(f"  compressed to {compressed_size} bytes (sha256:{compressed_digest_hex[:16]}...)")

        # Upload blobs (streaming via curl)
        config_digest = blob_upload_file(str(config_path), config_digest_hex)
        layer_digest = blob_upload_file(tmp.name, compressed_digest_hex)

    finally:
        os.unlink(tmp.name)

    # Build clean manifest
    manifest_v2 = json.dumps({
        "schemaVersion": 2,
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "config": {
            "mediaType": "application/vnd.oci.image.config.v1+json",
            "digest": config_digest,
            "size": config_size,
        },
        "layers": [
            {
                "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
                "digest": layer_digest,
                "size": compressed_size,
            }
        ],
    }).encode()

    # Push manifest via curl (PUT /v2/<name>/manifests/<tag>)
    import subprocess as sp
    manifest_url = f"https://{REGISTRY}/v2/{REPO}/manifests/{TAG}"
    print(f"Pushing manifest ({len(manifest_v2)} bytes)...")
    mf_tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".json")
    try:
        mf_tmp.write(manifest_v2)
        mf_tmp.close()
        proc = sp.run([
            "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
            "-X", "PUT",
            "-H", f"Authorization: Bearer {get_bearer_token()}",
            "-H", "Content-Type: application/vnd.oci.image.manifest.v1+json",
            "--data-binary", f"@{mf_tmp.name}",
            manifest_url
        ], capture_output=True, text=True)
        code = proc.stdout.strip()
        if code not in ("201", "200"):
            print(f"ERROR: manifest push failed HTTP {code}: {proc.stderr[:200]}", file=sys.stderr)
            sys.exit(1)
        print(f"Push complete! (HTTP {code})")
    finally:
        os.unlink(mf_tmp.name)

    # Cleanup OCI dir
    shutil.rmtree(str(oci_dir))
    print(f"Cleaned up {oci_dir}")

if __name__ == "__main__":
    main()
