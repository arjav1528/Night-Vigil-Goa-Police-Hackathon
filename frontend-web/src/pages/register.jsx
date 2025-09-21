import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

export const Register = () => {
  const [empid, setEmpid] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState(""); // Added state
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const handleRegister = async (e) => {
    e.preventDefault();
    setError("");
    setSuccess("");

    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }

    try {
      const response = await fetch(
        `${import.meta.env.VITE_BACKEND_URL}/users/admin/register`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ empid, password }),
        }
      );

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.detail || "Registration failed");
      }

      setSuccess("Registration successful! You can now log in.");
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-background p-4">
      <div className="p-8 w-full max-w-md bg-surface rounded-lg shadow-lg">
        <h2 className="text-headline-md font-bold text-center text-primary">
          Admin Register
        </h2>
        <form onSubmit={handleRegister} className="mt-8 space-y-6">
          <div>
            <label className="text-body-md font-medium text-on-surface">
              Employee ID
            </label>
            <input
              type="text"
              value={empid}
              onChange={(e) => setEmpid(e.target.value)}
              className="mt-1 w-full px-4 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-secondary focus:border-secondary text-on-surface"
              required
            />
          </div>
          <div>
            <label className="text-body-md font-medium text-on-surface">
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 w-full px-4 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-secondary focus:border-secondary text-on-surface"
              required
            />
          </div>
          <div>
            <label className="text-body-md font-medium text-on-surface">
              Confirm Password
            </label>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="mt-1 w-full px-4 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-secondary focus:border-secondary text-on-surface"
              required
            />
          </div>
          {error && <p className="text-error text-sm">{error}</p>}
          {success && <p className="text-green-600 text-sm">{success}</p>}
          <button
            type="submit"
            className="w-full py-2 px-4 rounded-md text-on-primary bg-primary hover:bg-secondary font-bold text-label-lg transition-colors"
          >
            REGISTER
          </button>
        </form>
        <div className="mt-4 text-center">
          <p className="text-body-md font-medium text-on-surface">
            Already an admin?{" "}
            <a href="/login" className="text-primary hover:underline">
              Log in
            </a>
          </p>
        </div>
      </div>
    </div>
  );
};
