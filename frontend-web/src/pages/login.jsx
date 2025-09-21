import { useState } from "react";
import { useNavigate } from "react-router-dom";
import Emblem from "../assets/Emblem.png";

export const Login = ({ onLogin }) => {
  const [empid, setEmpid] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setError("");

    try {
      const response = await fetch(
        `${import.meta.env.VITE_BACKEND_URL}/users/admin/login`,
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
        throw new Error(data.detail || "Login failed");
      }

      localStorage.setItem("accessToken", data.access_token);
      onLogin();
      navigate("/");
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen p-4 bg-background">
      <div className="p-8 w-full max-w-md bg-surface rounded-lg shadow-lg">
        <img src={Emblem} alt="Emblem of Goa Police" className="w-32 mx-auto mb-4" />
        <h2 className="text-headline-md font-bold text-center text-primary">
          Admin SHO Login
        </h2>
        <form onSubmit={handleLogin} className="mt-8 space-y-6">
          <div>
            <label className="text-body-md font-medium text-on-surface">
              Officer ID
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
          {error && <p className="text-error text-sm">{error}</p>}
          <button
            type="submit"
            className="w-full py-2 px-4 rounded-md text-on-primary bg-primary hover:bg-secondary font-bold text-label-lg transition-colors"
          >
            LOGIN
          </button>
        </form>
        <div className="mt-4 text-center">
          <p className="text-body-md font-medium text-on-surface">
            Admin Registration:{" "}
            <p className="text-primary hover:underline cursor-pointer">
              Contact IT
            </p>
          </p>
        </div>
      </div>
    </div>
  );
};