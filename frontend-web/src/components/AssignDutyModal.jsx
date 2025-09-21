import React, { useState } from "react";
import { IoCloseSharp } from "react-icons/io5";
import { MapContainer, TileLayer, Marker, useMapEvents } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { getMarkerColor } from "./MapComponent"; // Import the marker color function

const LocationMarker = ({ setPosition, color }) => {
  const [markerPosition, setMarkerPosition] = useState(null);
  const map = useMapEvents({
    click(e) {
      setMarkerPosition(e.latlng);
      setPosition(e.latlng);
    },
  });

  const onDragEnd = (e) => {
    const { lat, lng } = e.target.getLatLng();
    setPosition({ lat, lng });
  };

  const customIcon = new L.DivIcon({
    html: `<svg width="24" height="24" viewBox="0 0 24 24" fill="${color}" stroke="white" stroke-width="2" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="10"/></svg>`,
    iconSize: [24, 24],
    iconAnchor: [12, 12],
    popupAnchor: [0, -12],
    className: "leaflet-custom-marker",
  });

  return markerPosition === null ? null : (
    <Marker
      position={markerPosition}
      draggable={true}
      icon={customIcon}
      eventHandlers={{ dragend: onDragEnd }}
    />
  );
};

export const AssignDutyModal = ({ officer, onClose, onDutyAssigned }) => {
  const [location, setLocation] = useState("");
  const [position, setPosition] = useState(null);
  const [radius, setRadius] = useState("100");
  const [date, setDate] = useState("");
  const [startTime, setStartTime] = useState("");
  const [endTime, setEndTime] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!position) {
      setError("Please select a location on the map.");
      return;
    }
    setLoading(true);
    setError("");

    const formattedStartTime = new Date(
      `${date}T${startTime}:00Z`
    ).toISOString();
    const formattedEndTime = new Date(`${date}T${endTime}:00Z`).toISOString();

    const payload = {
      officerId: officer.id,
      location,
      latitude: position.lat,
      longitude: position.lng,
      radius: parseFloat(radius),
      startTime: formattedStartTime,
      endTime: formattedEndTime,
    };

    try {
      const token = localStorage.getItem("accessToken");
      const response = await fetch(
        `${import.meta.env.VITE_BACKEND_URL}/duties`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
            "ngrok-skip-browser-warning": "true",
          },
          body: JSON.stringify(payload),
        }
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || "Failed to assign duty.");
      }

      onDutyAssigned();
      onClose();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const markerColor = getMarkerColor(officer.id);

  return (
    <div className="fixed inset-0 z-50 bg-black/55 flex items-center justify-center p-4">
      <div className="bg-white p-8 rounded-lg shadow-2xl w-full max-w-2xl relative transform transition-all duration-300 ease-in-out scale-100 opacity-100">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-700 transition-colors cursor-pointer"
        >
          <IoCloseSharp size={24} />
        </button>
        <h2 className="text-2xl font-bold text-primary mb-6 border-b-2 border-blue-100 pb-2">
          Assign Duty to {officer.empid}
        </h2>
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="space-y-4">
            <div className="w-full h-80 rounded-lg overflow-hidden shadow-md">
              <MapContainer
                center={[15.3, 74.0]}
                zoom={10}
                scrollWheelZoom={true}
                className="w-full h-full"
              >
                <TileLayer
                  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                  attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                />
                <LocationMarker setPosition={setPosition} color={markerColor} />
              </MapContainer>
            </div>
            <div>
              <label
                htmlFor="location"
                className="block text-sm font-semibold text-gray-700 mb-1"
              >
                Location
              </label>
              <input
                id="location"
                type="text"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                required
                className="w-full px-4 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all duration-200"
                placeholder="e.g., Downtown Plaza"
              />
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label
                  htmlFor="latitude"
                  className="block text-sm font-semibold text-gray-700 mb-1"
                >
                  Latitude
                </label>
                <input
                  id="latitude"
                  type="number"
                  step="any"
                  value={position?.lat || ""}
                  readOnly
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all duration-200 bg-gray-100"
                  placeholder="Click on map to get coordinates"
                />
              </div>
              <div>
                <label
                  htmlFor="longitude"
                  className="block text-sm font-semibold text-gray-700 mb-1"
                >
                  Longitude
                </label>
                <input
                  id="longitude"
                  type="number"
                  step="any"
                  value={position?.lng || ""}
                  readOnly
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all duration-200 bg-gray-100"
                  placeholder="Click on map to get coordinates"
                />
              </div>
            </div>
          </div>
          <div>
            <label
              htmlFor="radius"
              className="block text-sm font-semibold text-gray-700 mb-1"
            >
              Radius (in meters)
            </label>
            <input
              id="radius"
              type="number"
              value={radius}
              onChange={(e) => setRadius(e.target.value)}
              required
              className="w-full px-4 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all duration-200"
              placeholder="Default: 100"
            />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label
                htmlFor="date"
                className="block text-sm font-semibold text-gray-700 mb-1"
              >
                Date
              </label>
              <input
                id="date"
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                required
                className="w-full px-4 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all duration-200"
              />
            </div>
            <div>
              <label
                htmlFor="startTime"
                className="block text-sm font-semibold text-gray-700 mb-1"
              >
                Start Time
              </label>
              <input
                id="startTime"
                type="time"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                required
                className="w-full px-4 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all duration-200"
              />
            </div>
          </div>
          <div>
            <label
              htmlFor="endTime"
              className="block text-sm font-semibold text-gray-700 mb-1"
            >
              End Time
            </label>
            <input
              id="endTime"
              type="time"
              value={endTime}
              onChange={(e) => setEndTime(e.target.value)}
              required
              className="w-full px-4 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all duration-200"
            />
          </div>
          {error && (
            <p className="text-sm text-red-500 text-center font-medium mt-4">
              {error}
            </p>
          )}
          <div className="flex justify-end gap-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-100 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className={`px-6 py-2 rounded-lg font-semibold text-white transition-colors duration-200 ${
                loading
                  ? "bg-blue-300 cursor-not-allowed"
                  : "bg-primary hover:bg-blue-700 cursor-pointer"
              }`}
            >
              {loading ? "Assigning..." : "Assign Duty"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};