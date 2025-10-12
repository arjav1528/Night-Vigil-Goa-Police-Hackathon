import React, { useState, useEffect } from "react";
import { IoCloseSharp } from "react-icons/io5";
import { FaMapMarkerAlt, FaCheckCircle, FaTimesCircle } from "react-icons/fa";
import { useAuth } from "../context/AuthContext";

export const LocationHistoryModal = ({ officer, duty, onClose }) => {
  const [locationHistory, setLocationHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const { getAuthHeaders } = useAuth();

  useEffect(() => {
    if (duty?.id) {
      fetchLocationHistory();
    }
  }, [duty?.id]);

  const fetchLocationHistory = async () => {
    setLoading(true);
    setError("");
    try {
      const headers = getAuthHeaders();
      const response = await fetch(
        `${import.meta.env.VITE_BACKEND_URL}/duties/location-history/${duty.id}`,
        { headers }
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || "Failed to fetch location history");
      }

      const data = await response.json();
      setLocationHistory(data.locationLogs || []);
    } catch (err) {
      setError(err.message);
      console.error("Error fetching location history:", err);
    } finally {
      setLoading(false);
    }
  };

  const formatDateTime = (timestamp) => {
    return new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: true,
    }).format(new Date(timestamp));
  };

  const getStatusColor = (isInside) => {
    return isInside ? "text-green-600" : "text-red-600";
  };

  const getStatusIcon = (isInside) => {
    return isInside ? (
      <FaCheckCircle className="text-green-500" />
    ) : (
      <FaTimesCircle className="text-red-500" />
    );
  };

  if (!duty) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/55 flex items-center justify-center p-4">
      <div className="bg-white p-6 rounded-lg shadow-2xl w-full max-w-4xl max-h-[80vh] relative overflow-hidden">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-700 transition-colors cursor-pointer z-10"
        >
          <IoCloseSharp size={24} />
        </button>
        
        <h2 className="text-2xl font-bold text-primary mb-4 pr-8">
          Location History - {officer.empid}
        </h2>
        
        <div className="mb-4 p-4 bg-gray-50 rounded-lg">
          <h3 className="font-semibold text-lg mb-2 flex items-center">
            <FaMapMarkerAlt className="mr-2 text-primary" />
            Duty Information
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <div>
              <span className="font-medium">Location:</span> {duty.location}
            </div>
            <div>
              <span className="font-medium">Radius:</span> {duty.radius}m
            </div>
            <div>
              <span className="font-medium">Coordinates:</span> {duty.latitude?.toFixed(6)}, {duty.longitude?.toFixed(6)}
            </div>
            <div>
              <span className="font-medium">Status:</span> 
              <span className={`ml-1 px-2 py-1 rounded text-xs ${
                duty.status === 'COMPLETED' ? 'bg-green-100 text-green-800' :
                duty.status === 'PENDING' ? 'bg-yellow-100 text-yellow-800' :
                'bg-red-100 text-red-800'
              }`}>
                {duty.status}
              </span>
            </div>
          </div>
        </div>

        <div className="overflow-y-auto max-h-[50vh]">
          {loading && (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
              <span className="ml-2">Loading location history...</span>
            </div>
          )}

          {error && (
            <div className="text-center py-8">
              <p className="text-red-500">{error}</p>
              <button
                onClick={fetchLocationHistory}
                className="mt-2 px-4 py-2 bg-primary text-white rounded hover:bg-blue-700 transition-colors"
              >
                Retry
              </button>
            </div>
          )}

          {!loading && !error && locationHistory.length === 0 && (
            <div className="text-center py-8 text-gray-500">
              No location history available for this duty.
            </div>
          )}

          {!loading && !error && locationHistory.length > 0 && (
            <div className="space-y-3">
              <h3 className="font-semibold text-lg mb-3">
                Location Logs ({locationHistory.length} entries)
              </h3>
              {locationHistory.map((log, index) => (
                <div
                  key={log.id}
                  className="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center mb-2">
                        {getStatusIcon(log.isInside)}
                        <span className={`ml-2 font-medium ${getStatusColor(log.isInside)}`}>
                          {log.isInside ? "Inside Duty Area" : "Outside Duty Area"}
                        </span>
                        <span className="ml-2 text-sm text-gray-500">
                          ({log.distance?.toFixed(2)}m from center)
                        </span>
                      </div>
                      
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-2 text-sm text-gray-600">
                        <div>
                          <span className="font-medium">Time:</span> {formatDateTime(log.timestamp)}
                        </div>
                        <div>
                          <span className="font-medium">Coordinates:</span> {log.latitude?.toFixed(6)}, {log.longitude?.toFixed(6)}
                        </div>
                        <div>
                          <span className="font-medium">Distance:</span> {log.distance?.toFixed(2)}m
                        </div>
                      </div>
                      
                      {log.remarks && (
                        <div className="mt-2 text-sm text-gray-700 bg-gray-100 p-2 rounded">
                          <span className="font-medium">Note:</span> {log.remarks}
                        </div>
                      )}
                    </div>
                    
                    <div className="text-xs text-gray-400 ml-4">
                      #{locationHistory.length - index}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="mt-6 flex justify-end">
          <button
            onClick={onClose}
            className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-100 transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
