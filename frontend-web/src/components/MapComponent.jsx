import React from "react";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

export const getMarkerColor = (officerId) => {
  const colors = [
    "#FF5733", // Vibrant Red-Orange
    "#FFB900", // Vivid Yellow
    "#00C853", // Bright Green
    "#00B8D4", // Cyan
    "#2979FF", // Strong Blue
    "#8E24AA", // Purple
    "#FF4081", // Pink
    "#F44336", // Red
    "#FFEB3B", // Yellow
    "#43A047", // Green
    "#1DE9B6", // Teal
    "#3949AB", // Indigo
    "#E040FB", // Magenta
    "#FF6D00", // Orange
    "#C51162", // Deep Pink
    "#00E676", // Neon Green
    "#0091EA", // Blue
    "#D500F9", // Violet
    "#FFD600", // Bright Yellow
    "#76FF03", // Lime
  ];
  let hash = 0;
  for (let i = 0; i < officerId.length; i++) {
    hash = officerId.charCodeAt(i) + ((hash << 5) - hash);
  }
  const colorIndex = Math.abs(hash) % colors.length;
  return colors[colorIndex];
};

const createCustomIcon = (color) => {
  const svg = `<svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M18 0C8.06 0 0 8.06 0 18C0 27.94 8.06 36 18 36C27.94 36 36 27.94 36 18C36 8.06 27.94 0 18 0Z" fill="${color}"/>
  <path d="M18 6C13.584 6 10 9.584 10 14C10 18.416 18 30 18 30C18 30 26 18.416 26 14C26 9.584 22.416 6 18 6ZM18 19C15.794 19 14 17.206 14 15C14 12.794 15.794 11 18 11C20.206 11 22 12.794 22 15C22 17.206 20.206 19 18 19Z" fill="white"/>
  </svg>`;
  return new L.DivIcon({
    html: svg,
    iconSize: [24, 24],
    iconAnchor: [12, 12],
    popupAnchor: [0, -12],
    className: "leaflet-custom-marker",
  });
};

export const MapComponent = ({ officersWithDuties }) => {
  const markers = officersWithDuties.filter((o) => o.assignedDuty);
  const center =
    markers.length > 0
      ? [markers[0].assignedDuty.latitude, markers[0].assignedDuty.longitude]
      : [15.2993, 74.124];

  return (
    <MapContainer
      center={center}
      zoom={10}
      scrollWheelZoom={true}
      className="w-full h-full z-20"
    >
      <TileLayer
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      />
      {markers.map((officer) => {
        const duty = officer.assignedDuty;
        const color = getMarkerColor(officer.id);
        const icon = createCustomIcon(color);
        return (
          <Marker
            key={officer.id}
            position={[duty.latitude, duty.longitude]}
            icon={icon}
          >
            <Popup>
              <div>
                Officer ID: <b>{officer.empid}</b>
              </div>
              Duty at: <b>{duty.location}</b>
            </Popup>
          </Marker>
        );
      })}
    </MapContainer>
  );
};