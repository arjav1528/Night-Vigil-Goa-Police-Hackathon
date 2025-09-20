from facenet_pytorch import MTCNN, InceptionResnetV1
import torch
import numpy as np
from PIL import Image

# --- Load Models Once ---
# These models are loaded into memory when the server starts, not on every request.
print("Loading Face Recognition models...")
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
mtcnn = MTCNN(keep_all=False, device=device)
resnet = InceptionResnetV1(pretrained='vggface2').eval().to(device)
print(f"Face Recognition models loaded onto {device}.")
# -------------------------

def extract_embedding(pil_image):
    """Extracts a face embedding from a PIL image."""
    face = mtcnn(pil_image)
    if face is None:
        return None
    
    with torch.no_grad():
        emb = resnet(face.unsqueeze(0).to(device))
    
    emb = emb.cpu().numpy()[0]
    emb = emb / np.linalg.norm(emb) # L2 Normalization
    
    return emb.tolist() # Return as a standard Python list for the database

def cosine_sim(a, b):
    """Calculates the cosine similarity between two embeddings."""
    return float(np.dot(a, b))