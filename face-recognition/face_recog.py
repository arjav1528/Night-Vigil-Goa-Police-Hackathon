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
    try:
        # Ensure image is in RGB format
        if pil_image.mode != 'RGB':
            pil_image = pil_image.convert('RGB')
        
        face = mtcnn(pil_image)
        if face is None:
            print("No face detected in the image")
            return None
        
        with torch.no_grad():
            emb = resnet(face.unsqueeze(0).to(device))
        
        emb = emb.cpu().numpy()[0]
        emb = emb / np.linalg.norm(emb) # L2 Normalization
        
        print(f"Successfully extracted embedding with shape: {emb.shape}")
        return emb.tolist() # Return as a standard Python list for the database
    except Exception as e:
        print(f"Error extracting embedding: {e}")
        return None

def cosine_sim(a, b):
    """Calculates the cosine similarity between two embeddings."""
    try:
        # Convert to numpy arrays if they're lists
        if isinstance(a, list):
            a = np.array(a)
        if isinstance(b, list):
            b = np.array(b)
        
        # Ensure embeddings are normalized
        a = a / np.linalg.norm(a)
        b = b / np.linalg.norm(b)
        
        similarity = float(np.dot(a, b))
        print(f"Calculated similarity: {similarity:.4f}")
        return similarity
    except Exception as e:
        print(f"Error calculating cosine similarity: {e}")
        return 0.0