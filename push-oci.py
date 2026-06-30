#!/usr/bin/env python3
"""
Push a BuildStream OCI layout to a Docker Registry v2 (e.g., ghcr.io)
using the raw HTTP API. Avoids all container-tool manifest bugs.
"""
import gzip, hashlib, json, os, shutil, sys, tempfile
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

REGISTRY = "ghcr.io"
REPO = "whelanh/tromso-kde-min"
TAG = "latest"
TOKEN = (Path.home() / "chessFiles" / "ghcr_token.txt").read_text().strip()

def req(method, url, data=None, headers=None):
    h = {
        "Authorization": f"Bearer {TOKEN}",
        "Accept": "application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json",
    }
    if headers:
        h.update(headers)
    r = Request(url, data=data, method=method, headers=h)
    try:
        return urlopen(r)
    except HTTPError as e:
        body = e.read().decode()
        print(f"HTTP {e.code} {e.reason}: {body}", file=sys.stderr)
        sys.exit(1)

def blob_exists(digest: str) -> bool:
    try:
        req("HEAD", f"https://{REGISTRY}/v2/{REPO}/blobs/{digest}")
        return True
    except HTTPError as e:
        if e.code == 404:
            return False
        raise

def blob_upload_file(path: str) -> str:
    """Upload a blob from a file and return its sha256 digest."""
    digest = "sha256:" + hashlib.sha256(open(path, "rb").read()).hexdigest()
    if blob_exists(digest):
        print(f"  blob {digest[:16]}... already exists")
        return digest
    size = os.path.getsize(path)
    data = open(path, "rb").read()
    resp = req("POST", f"https://{REGISTRY}/v2/{REPO}/blobs/uploads/")
    loc = resp.headers["Location"]
    if loc.startswith("/"):
        loc = f"https://{REGISTRY}{loc}"
    req("PUT", f"{loc}&digest={digest}", data=data,
        headers={"Content-Type": "application/octet-stream",
                 "Content-Length": str(size)})
    print(f"  blob {digest[:16]}... uploaded ({size} bytes)")
    return digest

def main():
    oci_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".build-out-kde")
    if not oci_dir.exists():
        print(f"Usage: {sys.argv[0]} [OCI_DIR]")
        print(f"  Pushes {REPO}:{TAG} to {REGISTRY}")
        sys.exit(1)

    # Read manifest
    index = json.loads((oci_dir / "index.json").read_text())
    mf_digest = index["manifests"][0]["digest"].replace("sha256:", "")
    manifest = json.loads((oci_dir / "blobs" / "sha256" / mf_digest).read_text())

    # Config blob
    cd = manifest["config"]["digest"].replace("sha256:", "")
    config_path = oci_dir / "blobs" / "sha256" / cd
    config_size = config_path.stat().st_size
    print(f"Config: {cd} ({config_size} bytes)")

    # Layer blob — compress with gzip
    ld = manifest["layers"][0]["digest"].replace("sha256:", "")
    layer_path = oci_dir / "blobs" / "sha256" / ld
    layer_raw_size = layer_path.stat().st_size
    print(f"Layer raw: {ld} ({layer_raw_size} bytes) — compressing...")

    # Stream-compress to temp file
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".tar.gz")
    try:
        with open(layer_path, "rb") as fin, gzip.GzipFile(fileobj=tmp, mode="wb") as gz:
            shutil.copyfileobj(fin, gz)
        tmp.close()
        compressed_size = os.path.getsize(tmp.name)
        print(f"  compressed to {compressed_size} bytes")

        # Upload blobs
        config_digest = blob_upload_file(str(config_path))
        layer_digest = blob_upload_file(tmp.name)

    finally:
        os.unlink(tmp.name)

    # Build clean manifest (1 layer, NO octet-stream bogus layer)
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
    print(f"Manifest: {len(manifest_v2)} bytes")

    # Push manifest
    resp = req("PUT",
               f"https://{REGISTRY}/v2/{REPO}/manifests/{TAG}",
               data=manifest_v2,
               headers={"Content-Type": "application/vnd.oci.image.manifest.v1+json"})
    digest = resp.headers.get("Docker-Content-Digest", "unknown")
    print(f"\nPush complete! Digest: {digest}")

    # Cleanup OCI dir
    shutil.rmtree(str(oci_dir))
    print(f"Cleaned up {oci_dir}")

if __name__ == "__main__":
    main()
