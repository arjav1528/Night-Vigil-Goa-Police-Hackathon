from fastapi import HTTPException
from enum import Enum
from typing import List, Optional
from datetime import datetime, timedelta
from passlib.context import CryptContext
import jwt

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def generate_id():
    import uuid
    return str(uuid.uuid4())





class Role(Enum):
    ADMIN = "ADMIN"
    OFFICER = "OFFICER"


class DutyStatus(Enum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    MISSED = "MISSED"


class NotificationType(Enum):
    ALERT = "ALERT"
    REMINDER = "REMINDER"
    MISSED_DUTY = "MISSED_DUTY"


class User:
    def __init__(
        self,
        id: str = generate_id(),
        empid: str = None,
        passwordHash: Optional[str] = None,
        role: Role = Role.OFFICER,
        profileImage: Optional[List[str]] = None,
        createdAt: Optional[datetime] = None,
        updatedAt: Optional[datetime] = None,
        dutyAssignments: Optional[List["DutyAssignment"]] = None,
        assignedDuties: Optional[List["DutyAssignment"]] = None,
        dutyLogs: Optional[List["DutyLog"]] = None,
        notifications: Optional[List["Notification"]] = None,
        reports: Optional[List["DutyReport"]] = None,
    ):
        self.id = id  
        self.empid = empid
        self.passwordHash = passwordHash
        self.role = Role(role) if isinstance(role, str) else role  
        self.profileImage = profileImage or []
        self.createdAt = createdAt or datetime.now()
        self.updatedAt = updatedAt
        self.dutyAssignments = dutyAssignments or []
        self.assignedDuties = assignedDuties or []
        self.dutyLogs = dutyLogs or []
        self.notifications = notifications or []
        self.reports = reports or []

    def set_password(self, password: str):
        self.passwordHash = pwd_context.hash(password)

    def verify_password(self, password: str) -> bool:
        if not self.passwordHash:
            print("No password hash set for user.")
            return False
        return pwd_context.verify(password, self.passwordHash)

    def generate_token(self, secret_key, expiration_days=2):
        payload = {
            "empid": self.empid,
            "role": self.role.value,
            "exp": datetime.utcnow() + timedelta(days=expiration_days)
        }
        token = jwt.encode(payload, secret_key, algorithm="HS256")
        return token
    
    def to_dict(self):
        return {
            "id": self.id,
            "empid": self.empid,
            "role": self.role.value if isinstance(self.role, Enum) else self.role,
            "profileImage": self.profileImage,
            "passwordHash": self.passwordHash,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }
    

class FaceEmbedding:
    def __init__(
        self,
        userId: str,
        embedding: List[float],
        createdAt: Optional[datetime] = None,
        user: Optional[User] = None,
    ):
        self.id = generate_id()
        self.userId = userId
        self.embedding = embedding
        self.createdAt = createdAt or datetime.now()
        self.user = user

    def to_dict(self):
        return {
            "id": self.id,
            "userId": self.userId,
            "embedding": self.embedding,
            "createdAt": self.createdAt.isoformat() if self.createdAt else None,
        }


class DutyAssignment:
    def __init__(
        self,
        officerId: str,
        assignedBy: str,
        location: str,
        latitude: float,
        longitude: float,
        radius: float = 100,
        startTime: datetime = None,
        endTime: datetime = None,
        status: DutyStatus = DutyStatus.PENDING,
        officer: Optional[User] = None,
        admin: Optional[User] = None,
        logs: Optional[List["DutyLog"]] = None,
    ):
        self.id = generate_id()
        self.officerId = officerId
        self.assignedBy = assignedBy
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.officer = officer
        self.admin = admin
        self.logs = logs or []


    def to_dict(self):
        return {
            "id": self.id,
            "officerId": self.officerId,
            "assignedBy": self.assignedBy,
            "location": self.location,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "radius": self.radius,
            "startTime": self.startTime.isoformat() if self.startTime else None,
            "endTime": self.endTime.isoformat() if self.endTime else None,
            "status": self.status.value if isinstance(self.status, Enum) else self.status,
        }


class DutyLog:
    def __init__(
        self,
        dutyId: str,
        officerId: str,
        checkinTime: Optional[datetime] = None,
        selfiePath: Optional[str] = None,
        faceVerified: bool = False,
        locationVerified: bool = False,
        remarks: Optional[str] = None,
        duty: Optional[DutyAssignment] = None,
        officer: Optional[User] = None,
    ):
        self.id = generate_id()
        self.dutyId = dutyId
        self.officerId = officerId
        self.checkinTime = checkinTime or datetime.now()
        self.selfiePath = selfiePath
        self.faceVerified = faceVerified
        self.locationVerified = locationVerified
        self.remarks = remarks
        self.duty = duty
        self.officer = officer


    def to_dict(self):        
        return {
            "id": self.id,
            "dutyId": self.dutyId,
            "officerId": self.officerId,
            "checkinTime": self.checkinTime.isoformat() if self.checkinTime else None,
            "selfiePath": self.selfiePath,
            "faceVerified": self.faceVerified,
            "locationVerified": self.locationVerified,
            "remarks": self.remarks,
        }


class Notification:
    def __init__(
        self,
        userId: str,
        message: str,
        type: NotificationType,
        createdAt: Optional[datetime] = None,
        read: bool = False,
        user: Optional[User] = None,
    ):
        self.id = generate_id()
        self.userId = userId
        self.message = message
        self.type = type
        self.createdAt = createdAt or datetime.now()
        self.read = read
        self.user = user


    def to_dict(self):
        return {
            "id": self.id,
            "userId": self.userId,
            "message": self.message,
            "type": self.type.value if isinstance(self.type, Enum) else self.type,
            "createdAt": self.createdAt.isoformat() if self.createdAt else None,
            "read": self.read,
        }


class DutyReport:
    def __init__(
        self,
        officerId: str,
        date: datetime,
        totalAssigned: int = 0,
        completed: int = 0,
        missed: int = 0,
        complianceRate: float = 0.0,
        officer: Optional[User] = None,
    ):
        self.id = generate_id()
        self.officerId = officerId
        self.date = date
        self.totalAssigned = totalAssigned
        self.completed = completed
        self.missed = missed
        self.complianceRate = complianceRate
        self.officer = officer

    
    def to_dict(self):
        return {
            "id": self.id,
            "officerId": self.officerId,
            "date": self.date.isoformat() if self.date else None,
            "totalAssigned": self.totalAssigned,
            "completed": self.completed,
            "missed": self.missed,
            "complianceRate": self.complianceRate,
        }
