import React, { useState, useEffect } from "react";

export const Dashboard = ({ onLogout }) => {
  const [officers, setOfficers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [mapIframeSrc, setMapIframeSrc] = useState(
    "https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d492479.1875141335!2d74.00641279999999!3d15.349728500000001!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3bbfba106336b741%3A0xeaf887ff62f34092!2sGoa!5e0!3m2!1sen!2sin!4v1758437603365!5m2!1sen!2sin"
  );

  useEffect(() => {
    const fetchOfficers = async () => {
      setLoading(true);
      setError("");
      try {
        const token = localStorage.getItem("accessToken");
        if (!token) {
          throw new Error("No access token found. Please log in.");
        }

        const response = await fetch(
          `${import.meta.env.VITE_BACKEND_URL}/duties/users/all`,
          {
            headers: {
              Authorization: `Bearer ${token}`,
              "ngrok-skip-browser-warning": "true", // Added header to bypass ngrok warning page
            },
          }
        );

        const contentType = response.headers.get("content-type");
        if (
          !response.ok ||
          !contentType ||
          !contentType.includes("application/json")
        ) {
          const text = await response.text();
          try {
            const errorData = JSON.parse(text);
            throw new Error(errorData.detail || "Failed to fetch officers.");
          } catch {
            throw new Error(
              "Failed to fetch officers. The server might be returning an error page instead of a JSON response."
            );
          }
        }

        const data = await response.json();
        setOfficers(data);
      } catch (err) {
        setError(err.message);
        console.error("Error fetching officers: ", err);
      } finally {
        setLoading(false);
      }
    };

    fetchOfficers();
  }, []);

  return (
    <div className="flex h-screen bg-background text-on-background">
      {/* Sidebar - Officer List */}
      <div className="w-1/2 border-r border-gray-200 overflow-y-auto">
        <div className="p-4 flex justify-between items-center bg-primary text-on-primary">
          <h1 className="text-title-lg font-bold">Officers</h1>
          <button
            onClick={onLogout}
            className="px-3 py-1 bg-secondary text-on-secondary rounded-md text-label-lg"
          >
            Logout
          </button>
        </div>
        {loading && <p className="p-4 text-center">Loading officers...</p>}
        {error && <p className="p-4 text-error text-center">{error}</p>}
        {!loading && !error && (
          <ul className="divide-y divide-gray-200">
            {officers.map((officer) => (
              <li
                key={officer.id}
                className="p-4 hover:bg-gray-100 cursor-pointer"
              >
                <div className="font-semibold text-on-surface">
                  Employee ID: {officer.empid}
                </div>
                <div className="text-sm text-gray-500">
                  Role: {officer.role}
                </div>
                <button className="mt-2 px-3 py-1 text-sm text-primary border border-primary rounded-md">
                  Assign Duty
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Main Content - Map Embed */}
      <div className="w-1/2 flex-1">
        <div className="p-4 bg-primary text-on-primary">
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
    </div>
  );
};
