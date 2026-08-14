import io
import numpy as np
import joblib
from fastapi import FastAPI, File, UploadFile
from PIL import Image
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input

app = FastAPI()

IMG_SIZE = (224, 224)

# Disease classes, from disease_dataset_cropped/ folder names (= the model's raw
# class labels, since train_disease_model.py uses os.listdir() directly as labels)
DISEASE_INFO = {
    "Bacterial": {
        "label": "Bacterial Infection",
        "recommendation": "Signs of bacterial infection detected. Remove affected leaves, "
                           "improve airflow, and avoid overhead watering to limit spread.",
    },
    "bottom rot": {
        "label": "Bottom Rot",
        "recommendation": "Signs of bottom rot detected. Reduce soil/water contact with "
                           "lower leaves and improve drainage around the base of the plant.",
    },
    "Downy_mildew": {
        "label": "Downy Mildew",
        "recommendation": "Signs of downy mildew detected. Increase air circulation, reduce "
                           "leaf wetness duration, and remove affected leaves promptly.",
    },
    "Lettuce - Anthracnose": {
        "label": "Anthracnose",
        "recommendation": "Signs of anthracnose detected. Remove infected leaves and avoid "
                           "splashing water onto foliage, which spreads spores.",
    },
    "lettuce mosaic virus": {
        "label": "Lettuce Mosaic Virus",
        "recommendation": "Signs of lettuce mosaic virus detected. Infected plants can't be "
                           "cured — remove and isolate them to protect the rest of the tower, "
                           "and control aphids, which spread this virus.",
    },
    "Powdery_mildew": {
        "label": "Powdery Mildew",
        "recommendation": "Signs of powdery mildew detected. Improve airflow and reduce "
                           "humidity around the leaves; remove heavily affected foliage.",
    },
    "Septoria_Blight": {
        "label": "Septoria Blight",
        "recommendation": "Signs of Septoria blight detected. Remove affected leaves promptly "
                           "and avoid overhead watering to reduce spore spread.",
    },
}

print("Loading MobileNetV2 feature extractor...")
feature_extractor = MobileNetV2(
    input_shape=IMG_SIZE + (3,),
    include_top=False,
    pooling="avg",
    weights="imagenet",
)

print("Loading disease classifier...")
disease_clf = joblib.load("lettuce_disease_model.pkl")

print("Vision service ready.")


def preprocess(image_bytes: bytes) -> np.ndarray:
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img = img.resize(IMG_SIZE)
    arr = np.array(img).astype("float32")
    arr = np.expand_dims(arr, axis=0)  # model expects a batch, even of 1
    arr = preprocess_input(arr)
    return arr


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    image_bytes = await file.read()
    arr = preprocess(image_bytes)

    features = feature_extractor.predict(arr, verbose=0)

    disease_pred = disease_clf.predict(features)[0]
    disease_probs = disease_clf.predict_proba(features)[0]
    disease_confidence = float(max(disease_probs))
    disease_info = DISEASE_INFO.get(
        disease_pred, {"label": disease_pred, "recommendation": ""}
    )

    return {
        "nutrient_class": "Not analyzed",
        "nutrient_confidence": 0.0,
        "disease_class": disease_info["label"],
        "disease_confidence": disease_confidence,
        "recommendation": disease_info["recommendation"] or "No specific recommendation available.",
    }