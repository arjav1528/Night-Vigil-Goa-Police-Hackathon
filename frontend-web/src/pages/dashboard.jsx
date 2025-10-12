import { useState, useEffect } from "react";
import { FaUserCircle } from "react-icons/fa";
import { IoIosLogOut } from "react-icons/io";
import { FaCheckCircle, FaTimesCircle } from "react-icons/fa";
import { useAuth } from "../context/AuthContext";
import { AssignDutyModal } from "../components/AssignDutyModal";
import { MapComponent, getMarkerColor } from "../components/MapComponent";
import { LocationHistoryModal } from "../components/LocationHistoryModal";

export const Dashboard = () => {
  const [officers, setOfficers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedOfficer, setSelectedOfficer] = useState(null);
  const [showLocationHistory, setShowLocationHistory] = useState(false);
  const [selectedOfficerForHistory, setSelectedOfficerForHistory] = useState(null);
  const { logout, getAuthHeaders } = useAuth();

  const fetchDashboardData = async () => {
    setLoading(true);
    setError("");
    try {
      const headers = getAuthHeaders();

      const [officersResponse, dutiesResponse] = await Promise.all([
        fetch(`${import.meta.env.VITE_BACKEND_URL}/duties/users/all`, {
          headers,
        }),
        fetch(`${import.meta.env.VITE_BACKEND_URL}/duties`, { headers }),
      ]);

      const officersData = await handleResponse(officersResponse, "officers");
      const dutiesData = await handleResponse(dutiesResponse, "duties");
  
      // Fix the data structure access - backend returns {users: [], count: number} and {duties: [], count: number}
      const officers = officersData.users || [];
      const duties = dutiesData.duties || [];

      const dutiesMap = {};
      duties.forEach((duty) => {
        dutiesMap[duty.officerId] = duty;
      });

      const mergedOfficers = await Promise.all(
        officers.map(async (officer) => {
          const assignedDuty = dutiesMap[officer.id] || null;
          let verificationData = null;

          if (assignedDuty) {
            try {
              const verificationResponse = await fetch(
                `${import.meta.env.VITE_BACKEND_URL}/duties/location-update/${
                  assignedDuty.officerId
                }`,
                { headers }
              );
              verificationData = await handleResponse(
                verificationResponse,
                "location-update"
              );
            } catch (verifError) {
              console.error(
                `Failed to fetch verification data for officer ${officer.empid}:`,
                verifError
              );
            }
          }

          return {
            ...officer,
            assignedDuty,
            verificationData,
          };
        })
      );

      setOfficers(mergedOfficers);
    } catch (err) {
      setError(err.message);
      console.error("Error fetching dashboard data: ", err);
      
      // If unauthorized, logout the user
      if (err.message.includes('401') || err.message.includes('unauthorized')) {
        logout();
      }
    } finally {
      setLoading(false);
    }
  };

  const handleResponse = async (response, dataType) => {
    const contentType = response.headers.get("content-type");
    if (
      !response.ok ||
      !contentType ||
      !contentType.includes("application/json")
    ) {
      const text = await response.text();
      try {
        const errorData = JSON.parse(text);
        throw new Error(errorData.detail || `Failed to fetch ${dataType}.`);
      } catch {
        throw new Error(
          `Failed to fetch ${dataType}. The server might be returning an error page.`
        );
      }
    }
    return response.json();
  };

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const openAssignModal = (officer) => {
    setSelectedOfficer(officer);
    setShowAssignModal(true);
  };

  const closeAssignModal = () => {
    setShowAssignModal(false);
    setSelectedOfficer(null);
  };

  const handleDutyAssigned = () => {
    fetchDashboardData();
  };

  const handleLogout = () => {
    logout();
  };

  const openLocationHistory = (officer) => {
    setSelectedOfficerForHistory(officer);
    setShowLocationHistory(true);
  };

  const closeLocationHistory = () => {
    setShowLocationHistory(false);
    setSelectedOfficerForHistory(null);
  };

  const getStatusColor = (status) => {
    switch (status) {
      case "COMPLETED":
        return "text-green-500";
      case "PENDING":
        return "text-orange-500";
      case "MISSED":
        return "text-red-500";
      default:
        return "text-gray-500";
    }
  };

  const isOfficerAvailableForAssignment = (officer) => {
    // Officer is available if they have no duty or their duty is completed/missed and has ended
    if (!officer.assignedDuty) {
      return true;
    }
    
    const now = new Date();
    const dutyEndTime = new Date(officer.assignedDuty.endTime);
    
    // Only allow reassignment if duty has ended AND status is completed/missed
    return (
      (officer.assignedDuty.status === "COMPLETED" || officer.assignedDuty.status === "MISSED") &&
      now > dutyEndTime
    );
  };

  const getAssignButtonText = (officer) => {
    if (!officer.assignedDuty) {
      return "Assign Duty";
    }
    
    const now = new Date();
    const dutyEndTime = new Date(officer.assignedDuty.endTime);
    
    // If duty is currently active (hasn't ended yet)
    if (now <= dutyEndTime) {
      switch (officer.assignedDuty.status) {
        case "COMPLETED":
          return "Currently On Duty";
        case "PENDING":
          return "Currently On Duty";
        case "MISSED":
          return "Duty In Progress";
        default:
          return "Currently On Duty";
      }
    }
    
    // If duty has ended
    switch (officer.assignedDuty.status) {
      case "COMPLETED":
        return "Reassign Duty";
      case "MISSED":
        return "Reassign Duty";
      case "PENDING":
        return "Reassign Duty";
      default:
        return "Reassign Duty";
    }
  };

  const formatDutyTime = (startTime, endTime) => {
    // Parse UTC times from backend and convert to local time for display
    const start = new Date(startTime);
    const end = new Date(endTime);
    
    const startDate = start.toLocaleDateString();
    const endDate = end.toLocaleDateString();
    
    const startTimeFormatted = new Intl.DateTimeFormat("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).format(start);
    
    const endTimeFormatted = new Intl.DateTimeFormat("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).format(end);
    
    // If dates are the same, show only time
    if (startDate === endDate) {
      return `${startTimeFormatted} - ${endTimeFormatted}`;
    }
    
    // If dates are different, show full date and time
    const startFullFormatted = new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).format(start);
    
    const endFullFormatted = new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).format(end);
    
    return `${startFullFormatted} - ${endFullFormatted}`;
  };

  return (
    <div className="flex flex-col lg:flex-row h-screen bg-background text-on-background">
      {/* Sidebar - Officer List */}
      <div className="w-full lg:w-1/3 border-r border-gray-200 overflow-y-auto shadow-md">
        <div className="p-4 flex justify-between items-center bg-primary text-on-primary shadow-lg sticky top-0 z-10">
          <h1 className="text-title-lg font-bold">Officers</h1>
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 px-3 py-1 bg-secondary text-on-secondary rounded-md text-label-lg hover:bg-opacity-80 transition-colors cursor-pointer"
          >
            <IoIosLogOut />
            Logout
          </button>
        </div>
        {loading && <p className="p-4 text-center">Loading officers...</p>}
        {error && <p className="p-4 text-error text-center">{error}</p>}
        {!loading && !error && (
          <ul className="p-4 space-y-4">
            {officers.map((officer) => (
              <li
                key={officer.id}
                className="bg-surface rounded-lg shadow-sm p-4 hover:bg-gray-50 transition-colors cursor-pointer flex items-center gap-4"
              >
                <FaUserCircle size={40} className="text-primary" />
                <div className="flex-1">
                  <div className="font-semibold text-on-surface">
                    Officer ID: {officer.empid}
                  </div>
                  <div className="text-xs text-gray-500">
                    Role: {officer.role}
                  </div>
                  {officer.assignedDuty && (
                    <>
                      <div className="text-sm text-gray-800 mt-1 flex items-center">
                        <span
                          className="w-3 h-3 rounded-full mr-2"
                          style={{
                            backgroundColor: getMarkerColor(officer.id),
                          }}
                        ></span>
                        Duty at:{" "}
                        <span className="font-semibold ml-1">
                          {officer.assignedDuty.location}
                        </span>
                      </div>
                      <div className="text-sm text-gray-800 mt-1 flex items-center">
                        <span className="font-medium mr-1">Time:</span>
                        <span>
                          {formatDutyTime(officer.assignedDuty.startTime, officer.assignedDuty.endTime)}
                        </span>
                      </div>
                      <div
                        className={`text-sm font-medium flex flex-row gap-2 mt-1`}
                      >
                        Status:
                        <p
                          className={` ${getStatusColor(
                            officer.assignedDuty.status
                          )}`}
                        >
                          {officer.assignedDuty.status}
                        </p>
                      </div>
                      {officer.verificationData && (
                        <div className="text-sm text-gray-500 mt-1 flex items-center gap-4">
                          <div className="flex items-center">
                            {officer.verificationData.faceVerified ? (
                              <FaCheckCircle className="text-green-500 mr-1" />
                            ) : (
                              <FaTimesCircle className="text-red-500 mr-1" />
                            )}
                            <span className="text-on-surface">
                              Face Verified
                            </span>
                          </div>
                          <div className="flex items-center">
                            {officer.verificationData.locationVerified ? (
                              <FaCheckCircle className="text-green-500 mr-1" />
                            ) : (
                              <FaTimesCircle className="text-red-500 mr-1" />
                            )}
                            <span className="text-on-surface">
                              Location Verified
                            </span>
                          </div>
                        </div>
                      )}
                      
                      {/* Add location history button */}
                      <div className="mt-2">
                        <button
                          onClick={() => openLocationHistory(officer)}
                          className="text-xs px-2 py-1 bg-blue-100 text-blue-800 rounded hover:bg-blue-200 transition-colors"
                        >
                          View Location History
                        </button>
                      </div>
                    </>
                  )}
                </div>
                <button
                  onClick={() => openAssignModal(officer)}
                  className={`px-3 py-1 text-sm rounded-md transition-colors ${
                    isOfficerAvailableForAssignment(officer)
                      ? "text-primary border border-primary hover:bg-primary hover:text-on-primary cursor-pointer"
                      : "bg-gray-400 text-gray-700 cursor-not-allowed"
                  }`}
                  disabled={!isOfficerAvailableForAssignment(officer)}
                >
                  {getAssignButtonText(officer)}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Main Content - Map Embed */}
      <div className="w-full lg:w-2/3 min-h-[320px] flex-1 flex flex-col">
        <div className="flex-1 h-full overflow-hidden">
          <MapComponent officersWithDuties={officers} />
        </div>
      </div>
      {/* Modals */}
      {showAssignModal && selectedOfficer && (
        <AssignDutyModal
          officer={selectedOfficer}
          onClose={closeAssignModal}
          onDutyAssigned={handleDutyAssigned}
        />
      )}
      
      {showLocationHistory && selectedOfficerForHistory && (
        <LocationHistoryModal
          officer={selectedOfficerForHistory}
          duty={selectedOfficerForHistory.assignedDuty}
          onClose={closeLocationHistory}
        />
      )}
    </div>
  );
};