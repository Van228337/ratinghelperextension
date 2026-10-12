import os
import zipfile

dist_dir = r"d:\Загрузки\susu-rating-helper-dist"
zip_path = r"d:\Загрузки\susu-rating-helper-v1.2.0.zip"

if os.path.exists(zip_path):
    os.remove(zip_path)

with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(dist_dir):
        for file in files:
            full_path = os.path.join(root, file)
            # Принудительно используем прямые слэши '/' (стандарт ZIP для Linux/Web Store/Opera)
            rel_path = os.path.relpath(full_path, dist_dir).replace("\\", "/")
            zipf.write(full_path, rel_path)

print(f"Archive successfully created: {zip_path}")
