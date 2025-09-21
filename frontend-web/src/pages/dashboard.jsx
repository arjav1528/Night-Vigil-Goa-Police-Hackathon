import { useState, useEffect } from "react";
import { FaUserCircle } from "react-icons/fa";
import { IoIosLogOut } from "react-icons/io";
import { FaCheckCircle, FaTimesCircle } from "react-icons/fa";
import { AssignDutyModal } from "../components/AssignDutyModal";
import { MapComponent, getMarkerColor } from "../components/MapComponent";

export const Dashboard = ({ onLogout }) => {
  const [officers, setOfficers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedOfficer, setSelectedOfficer] = useState(null);

  const fetchDashboardData = async () => {
    setLoading(true);
    setError("");
    try {
      const token = localStorage.getItem("accessToken");
      if (!token) {
        throw new Error("No access token found. Please log in.");
      }

      const headers = {
        Authorization: `Bearer ${token}`,
        "ngrok-skip-browser-warning": "true",
      };

      const [officersResponse, dutiesResponse] = await Promise.all([
        fetch(`${import.meta.env.VITE_BACKEND_URL}/duties/users/all`, {
          headers,
        }),
        fetch(`${import.meta.env.VITE_BACKEND_URL}/duties`, { headers }),
      ]);

      const officersData = await handleResponse(officersResponse, "officers");
      const dutiesData = await handleResponse(dutiesResponse, "duties");

      const dutiesMap = {};
      dutiesData.forEach((duty) => {
        dutiesMap[duty.officerId] = duty;
      });

      const mergedOfficers = await Promise.all(
        officersData.map(async (officer) => {
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

  return (
    <div className="flex flex-col lg:flex-row h-screen bg-background text-on-background">
      {/* Sidebar - Officer List */}
      <div className="w-full lg:w-1/3 border-r border-gray-200 overflow-y-auto shadow-md">
        <div className="p-4 flex justify-between items-center bg-primary text-on-primary shadow-lg sticky top-0 z-10">
          <h1 className="text-title-lg font-bold">Officers</h1>
          <button
            onClick={onLogout}
            className="flex items-center gap-2 px-3 py-1 bg-secondary text-on-secondary rounded-md text-label-lg hover:bg-opacity-80 transition-colors"
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
                  <div className="text-sm text-gray-500">
                    Role: {officer.role}
                  </div>
                  {officer.assignedDuty && (
                    <>
                      <div className="text-sm text-gray-500 mt-1 flex items-center">
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
                      {/* New section for duty start and end times */}
                      <div className="text-xs text-gray-800 mt-1 flex items-center">
                        <span className="font-semibold mr-1">Time:</span>
                        <span>
                          {new Intl.DateTimeFormat("en-US", {
                            hour: "2-digit",
                            minute: "2-digit",
                          }).format(new Date(officer.assignedDuty.startTime))}
                          {" - "}
                          {new Intl.DateTimeFormat("en-US", {
                            hour: "2-digit",
                            minute: "2-digit",
                          }).format(new Date(officer.assignedDuty.endTime))}
                        </span>
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
                    </>
                  )}
                </div>
                <button
                  onClick={() => openAssignModal(officer)}
                  className={`px-3 py-1 text-sm rounded-md transition-colors ${
                    officer.assignedDuty
                      ? "bg-gray-400 text-gray-700 cursor-not-allowed"
                      : "text-primary border border-primary hover:bg-primary hover:text-on-primary"
                  }`}
                  disabled={!!officer.assignedDuty}
                >
                  {officer.assignedDuty ? "Assigned" : "Assign Duty"}
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
      {showAssignModal && selectedOfficer && (
        <AssignDutyModal
          officer={selectedOfficer}
          onClose={closeAssignModal}
          onDutyAssigned={handleDutyAssigned}
        />
      )}
    </div>
  );
};
