import React, { useState } from 'react';
import { IoCloseSharp } from "react-icons/io5";

export const AssignDutyModal = ({ officer, onClose, onDutyAssigned }) => {
  const [location, setLocation] = useState('');
  const [latitude, setLatitude] = useState('');
  const [longitude, setLongitude] = useState('');
  const [radius, setRadius] = useState('100'); // Default to 100 as per schema
  const [date, setDate] = useState('');
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    const formattedStartTime = new Date(`${date}T${startTime}:00Z`).toISOString();
    const formattedEndTime = new Date(`${date}T${endTime}:00Z`).toISOString();

    const payload = {
      officerId: officer.id,
      location,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      radius: parseFloat(radius),
      startTime: formattedStartTime,
      endTime: formattedEndTime,
    };

    try {
      const token = localStorage.getItem("accessToken");
      const response = await fetch(`${import.meta.env.VITE_BACKEND_URL}/duties`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true'
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to assign duty.');
      }
      
      onDutyAssigned(); // Signal to the parent to refresh data
      onClose();      // Close the modal
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/55 flex items-center justify-center p-4">
      <div className="bg-surface p-6 rounded-lg shadow-xl w-full max-w-lg relative">
        <button onClick={onClose} className="absolute top-4 right-4 text-gray-500 hover:text-gray-800 cursor-pointer">
          <IoCloseSharp size={24} />
        </button>
        <h2 className="text-title-lg font-bold text-primary mb-4">Assign Duty to {officer.empid}</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-on-surface">Location</label>
            <input type="text" value={location} onChange={(e) => setLocation(e.target.value)} required 
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary"
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-on-surface">Latitude</label>
              <input type="number" step="any" value={latitude} onChange={(e) => setLatitude(e.target.value)} required 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-on-surface">Longitude</label>
              <input type="number" step="any" value={longitude} onChange={(e) => setLongitude(e.target.value)} required 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary"
              />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-on-surface">Radius (in meters)</label>
            <input type="number" value={radius} onChange={(e) => setRadius(e.target.value)} required 
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary"
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-on-surface">Date</label>
              <input type="date" value={date} onChange={(e) => setDate(e.target.value)} required 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-on-surface">Start Time</label>
              <input type="time" value={startTime} onChange={(e) => setStartTime(e.target.value)} required 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary"
              />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-on-surface">End Time</label>
            <input type="time" value={endTime} onChange={(e) => setEndTime(e.target.value)} required 
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary"
            />
          </div>
          {error && <p className="text-sm text-error text-center">{error}</p>}
          <div className="flex justify-end gap-2 mt-6">
            <button type="button" onClick={onClose} 
              className="px-4 py-2 border border-gray-300 rounded-md text-on-surface hover:bg-gray-100 transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button type="submit" disabled={loading}
              className={`px-4 py-2 rounded-md font-bold text-on-primary transition-colors ${loading ? 'bg-gray-400' : 'bg-primary hover:bg-opacity-80 cursor-pointer'}`}
            >
              {loading ? 'Assigning...' : 'Assign Duty'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};