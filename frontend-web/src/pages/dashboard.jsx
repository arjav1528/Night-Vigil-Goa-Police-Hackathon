import React, { useState, useEffect } from "react";
import { FaUserCircle } from "react-icons/fa"; // Using react-icons for a cleaner look
import { IoIosLogOut } from "react-icons/io";
import { IoLocationSharp } from "react-icons/io5";
import { AssignDutyModal } from "../components/AssignDutyModal";

export const Dashboard = ({ onLogout }) => {
  const [officers, setOfficers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [selectedOfficer, setSelectedOfficer] = useState(null);

  const [mapIframeSrc, setMapIframeSrc] = useState(
    "https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d492479.1875141335!2d74.00641279999999!3d15.349728500000001!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3bbfba106336b741%3A0xeaf887ff62f34092!2sGoa!5e0!3m2!1sen!2sin!4v1758437603365!5m2!1sen!2sin"
  );

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

      const mergedOfficers = officersData.map((officer) => ({
        ...officer,
        assignedDuty: dutiesMap[officer.id] || null,
      }));

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
    // Re-fetch all data to show the updated assignment status
    fetchDashboardData();
  };

  return (
    <div className="flex h-screen bg-background text-on-background">
      {/* Sidebar - Officer List */}
      <div className="w-1/3 border-r border-gray-200 overflow-y-auto shadow-md">
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
                    Employee ID: {officer.empid}
                  </div>
                  <div className="text-sm text-gray-500">
                    Role: {officer.role}
                  </div>
                  {officer.assignedDuty && (
                    <div className="text-sm text-gray-500 mt-1 flex items-center">
                      <IoLocationSharp className="text-red-500 mr-1" />
                      Duty assigned at:{" "}
                      <span className="font-semibold ml-1">
                        {officer.assignedDuty.location}
                      </span>
                    </div>
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
      <div className="w-2/3 flex-1 flex flex-col">
        <div className="p-4 bg-primary text-on-primary shadow-lg sticky top-0 z-10 h-16">
          <h1 className="text-title-lg font-bold">Live Map</h1>
        </div>
        <div className="flex-1 h-full overflow-hidden">
          <iframe
            src={mapIframeSrc}
            width="100%"
            height="100%"
            style={{ border: 0 }}
            allowFullScreen=""
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
          />
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