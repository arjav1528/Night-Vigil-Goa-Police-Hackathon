### Night Vigil: Smart Patrolling Verification System

This repository contains the code for **Night Vigil**, a combined web and mobile solution designed to ensure transparency, accountability, and real-time monitoring of police patrolling duties. The system provides a robust framework for supervisors to assign and monitor patrols, while enabling officers to securely check in using facial recognition and location verification.

***

### 1. Features

The system is broken down into three main components, each with its own set of features.

#### **1.1. Admin Website (React)**

The web-based dashboard is built for SHOs (Station House Officers) to manage patrols and officers efficiently.

* **Dashboard Overview**: A real-time dashboard displaying all officers, their assigned duties, and a map with duty locations. The dashboard also indicates the verification status (face and location) of each officer's check-in.
* **Duty Assignment**: Admins can easily assign new duties by selecting a location on a map, setting a geofence radius, and defining a specific time window for the patrol.
* **Analytics and Reporting**: The system generates automated reports and analytics on duty compliance, historical patrolling data, and missed duties, enabling data-driven decision-making.

#### **1.2. Mobile App (Flutter)**

The mobile application, built with Flutter, is designed for police officers on patrol.

* **Secure Authentication**: Officers can register and log in using their Employee ID. Registration is a critical step, requiring at least three clear photos for facial recognition enrollment.
* **Duty Management**: The app displays an officer's assigned duties with their status (e.g., PENDING, COMPLETED, MISSED), location details, and time windows.
* **Geofenced Check-in**: To check in, an officer must be within the assigned geofence radius. The app automatically captures their GPS location and a timestamp.
* **Facial Recognition Verification**: The core verification step requires the officer to take a real-time selfie, which is then sent to the backend for facial recognition validation. This ensures the correct officer is performing the duty.
* **Background Monitoring & Alerts**: A background service monitors the officer's location during an active duty. If the officer moves outside the assigned geofence, a push notification is sent to them, and an alert is logged on the Admin Dashboard.

***

### 2. System Architecture

The system follows a microservices-based architecture, with a dedicated backend API and a separate facial recognition service.

#### **2.1. Backend (Flask & FastAPI)**

The backend is built with **Python using Flask and FastAPI**, and it uses a **PostgreSQL** database to store user and duty data. It acts as the central hub, handling all communication between the web and mobile applications and the facial recognition service.

#### **2.2. Facial Recognition Microservice (FastAPI)**

This is a standalone service built with **FastAPI** and containerized with **Docker**, dedicated solely to handling facial recognition tasks.

* **Face Detection**: Uses the `MTCNN` (Multi-task Cascaded Convolutional Networks) model to accurately detect and align faces within an image.
* **Embedding Generation**: Employs the `InceptionResnetV1` model, pre-trained on the `vggface2` dataset, to generate a 512-dimensional facial embedding (a numerical representation of a face).
* **Verification Logic**: When an officer checks in, the service compares the embedding from the new selfie to the stored embeddings for that user. It uses **cosine similarity** to measure the likeness, and a check-in is considered successful if the similarity score exceeds a predefined **threshold of 0.8**.

***

### 3. Backend Endpoints

The backend exposes a series of RESTful API endpoints for the web and mobile applications to interact with.

* `POST /users/register`: Registers a new officer. This endpoint creates the user in the database and then calls the face recognition microservice to enroll their face.
* `POST /users/login`: Authenticates an officer and returns a JWT token for future requests.
* `POST /users/admin/login`: Authenticates an admin and returns a JWT token.
* `GET /users/me`: Retrieves the profile information for the authenticated user (officer or admin).
* `POST /duties`: (Admin only) Creates a new duty assignment with location, radius, and time.
* `GET /duties`: (Admin only) Retrieves all duty assignments for all officers.
* `GET /duties/my-duties`: (Officer only) Retrieves all duties assigned to the current officer.
* `POST /duties/{duty_id}/checkin`: The primary endpoint for officers to check in. It triggers both location verification and facial recognition.
* `POST /duties/location-update`: Receives real-time location updates from the mobile app's background service. If a geofence breach is detected, it logs an alert.
* `GET /duties/location-update/{id}`: (Admin only) Retrieves the location history for a specific officer.

***

### 4. Setup Guide

To get the project running, you will need to set up each component individually.

#### **4.1. Prerequisites**

* Python 3.10+
* Node.js and npm
* Flutter SDK
* Docker and Docker Compose
* PostgreSQL

#### **4.2. Backend Setup**

1.  Navigate to the `backend` directory.
2.  Install dependencies: `pip install -r requirements.txt`.
3.  Set up your PostgreSQL database and update the connection string in the configuration.
4.  Run the backend server: `python app.py`.

#### **4.3. Facial Recognition Setup**

1.  Navigate to the `face-recognition` directory.
2.  Build the Docker image: `docker build -t face-recog .`.
3.  Run the container: `docker run -p 8001:8001 face-recog`.
4.  The service will be available at `http://localhost:8001`.

#### **4.4. Web Frontend Setup**

1.  Navigate to the `frontend-web` directory.
2.  Install dependencies: `npm install`.
3.  Start the development server: `npm run dev`.
4.  The website will be available at `http://localhost:5173`.

#### **4.5. Mobile App Setup**

1.  Navigate to the `app` directory.
2.  Ensure you have the Flutter SDK installed and configured.
3.  Connect to a device or start an emulator.
4.  Run the app: `flutter run`.
