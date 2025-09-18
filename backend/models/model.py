from enum import Enum
from typing import List, Optional
from datetime import datetime
from passlib.context import CryptContext
import uuid

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")




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
        empid: str,  # Employee ID instead of email
        passwordHash: Optional[str] = None,
        role: Role = Role.OFFICER,
        profileImage: Optional[str] = None,
        createdAt: Optional[datetime] = None,
        updatedAt: Optional[datetime] = None,
        dutyAssignments: Optional[List["DutyAssignment"]] = None,
        assignedDuties: Optional[List["DutyAssignment"]] = None,
        dutyLogs: Optional[List["DutyLog"]] = None,
        notifications: Optional[List["Notification"]] = None,
        reports: Optional[List["DutyReport"]] = None,
    ):
        self.id = None  # ID will be set by the database
        self.empid = empid
        self.passwordHash = passwordHash
        self.role = role
        self.profileImage = profileImage
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
            return False
        return pwd_context.verify(password, self.passwordHash)


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
        self.id = None  # ID will be set by the database
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
        self.id = None  # ID will be set by the database
        self.dutyId = dutyId
        self.officerId = officerId
        self.checkinTime = checkinTime or datetime.now()
        self.selfiePath = selfiePath
        self.faceVerified = faceVerified
        self.locationVerified = locationVerified
        self.remarks = remarks
        self.duty = duty
        self.officer = officer


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
        self.id = None  # ID will be set by the database
        self.userId = userId
        self.message = message
        self.type = type
        self.createdAt = createdAt or datetime.now()
        self.read = read
        self.user = user


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
        self.id = None  # ID will be set by the database
        self.officerId = officerId
        self.date = date
        self.totalAssigned = totalAssigned
        self.completed = completed
        self.missed = missed
        self.complianceRate = complianceRate
        self.officer = officer
