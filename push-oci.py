#!/usr/bin/env python3
"""
Push a BuildStream OCI layout to a Docker Registry v2 (e.g., ghcr.io)
using the raw HTTP API. Handles multi-layer manifests correctly.
"""
import base64, gzip, hashlib, json, os, shutil, sys, tempfile, tarfile
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

REGISTRY = "ghcr.io"
REPO = os.environ.get("OCI_REPO", "whelanh/tromso-kde-min")
TAG = os.environ.get("OCI_TAG", "latest")
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
    data = json.loads(urlopen(r).read())
    _bearer_token = data["token"]
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
        raise

def blob_exists(digest):
    try:
        req("HEAD", f"https://{REGISTRY}/v2/{REPO}/blobs/{digest}")
        return True
    except HTTPError as e:
        if e.code == 404:
            return False
        raise

def blob_upload_file(path):
    digest = "sha256:" + sha256_stream(path)
    if blob_exists(digest):
        print(f"  blob {digest[:16]}... already exists")
        return digest
    size = os.path.getsize(path)
    resp = req("POST", f"https://{REGISTRY}/v2/{REPO}/blobs/uploads/")
    loc = resp.headers["Location"]
    if loc.startswith("/"):
        loc = f"https://{REGISTRY}{loc}"
    sep = "&" if "?" in loc else "?"
    data = open(path, "rb").read()
    req("PUT", f"{loc}{sep}digest={digest}", data=data,
        headers={"Content-Type": "application/octet-stream",
                 "Content-Length": str(size)})
    print(f"  blob {digest[:16]}... uploaded ({size} bytes)")
    return digest

def compress_layer(layer_path):
    if layer_path.is_dir():
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".tar.gz")
        with gzip.GzipFile(fileobj=tmp, mode="wb") as gz:
            with tarfile.open(fileobj=gz, mode="w|") as tar:
                for item in sorted(os.listdir(str(layer_path))):
                    tar.add(os.path.join(str(layer_path), item), arcname=item)
        tmp.close()
        media_type = "application/vnd.oci.image.layer.v1.tar+gzip"
        return (Path(tmp.name), media_type, os.path.getsize(tmp.name), True)
    with open(str(layer_path), "rb") as f:
        magic = f.read(2)
    if magic == b'\x1f\x8b':
        return (layer_path, "application/vnd.oci.image.layer.v1.tar+gzip",
                os.path.getsize(str(layer_path)), False)
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".tar.gz")
    with open(str(layer_path), "rb") as fin, gzip.GzipFile(fileobj=tmp, mode="wb") as gz:
        shutil.copyfileobj(fin, gz)
    tmp.close()
    return (Path(tmp.name), "application/vnd.oci.image.layer.v1.tar+gzip",
            os.path.getsize(tmp.name), True)

def main():
    oci_dir_arg = sys.argv[1] if len(sys.argv) > 1 else ".build-out-kde"
    oci_dir = Path(oci_dir_arg)
    if not oci_dir.exists():
        print(f"Usage: {sys.argv[0]} [OCI_DIR]")
        sys.exit(1)

    print(f"Pushing {oci_dir} → {REGISTRY}/{REPO}:{TAG}")

    index = json.loads((oci_dir / "index.json").read_text())
    mf_digest = index["manifests"][0]["digest"].replace("sha256:", "")
    manifest = json.loads((oci_dir / "blobs" / "sha256" / mf_digest).read_text())
    print(f"Manifest has {len(manifest['layers'])} layer(s)")

    # Config blob
    cd = manifest["config"]["digest"].replace("sha256:", "")
    config_path = oci_dir / "blobs" / "sha256" / cd
    config_size = config_path.stat().st_size
    config_digest = blob_upload_file(str(config_path))
    print(f"Config: {config_digest} ({config_size} bytes)")

    # Layer blobs
    new_layers = []
    tmp_files = []
    try:
        for i, layer in enumerate(manifest["layers"]):
            ld = layer["digest"].replace("sha256:", "")
            layer_path = oci_dir / "blobs" / "sha256" / ld
            print(f"Layer {i}: {ld[:16]}... ({layer_path.stat().st_size} bytes)", end="")
            cpath, mt, csize, is_tmp = compress_layer(layer_path)
            if is_tmp:
                tmp_files.append(cpath)
            print(f" → {csize} bytes")
            cdigest = blob_upload_file(str(cpath))
            new_layers.append({"mediaType": mt, "digest": cdigest, "size": csize})

        # Build clean manifest
        manifest_v2 = json.dumps({
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "config": {
                "mediaType": "application/vnd.oci.image.config.v1+json",
                "digest": config_digest,
                "size": config_size,
            },
            "layers": new_layers,
        }, separators=(",", ":")).encode()
        print(f"Manifest: {len(manifest_v2)} bytes")

        manifest_url = f"https://{REGISTRY}/v2/{REPO}/manifests/{TAG}"
        resp = req("PUT", manifest_url, data=manifest_v2,
                   headers={"Content-Type": "application/vnd.oci.image.manifest.v1+json"})
        digest = resp.headers.get("Docker-Content-Digest", "unknown")
        print(f"\nPush complete! Digest: {digest}")
    finally:
        for t in tmp_files:
            if t.exists():
                os.unlink(str(t))

if __name__ == "__main__":
    try:
        main()
    except HTTPError as e:
        body = e.read().decode()
        print(f"HTTP {e.code}: {body[:300]}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
