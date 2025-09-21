import { BrowserRouter as Router, Routes, Route } from "react-router-dom";

function App() {
  return (
    <>
      <Router>
        <Sidebar />
        <Routes>
          <Route path="/" element={<Homepage />} />
        </Routes>
      </Router>
    </>
  );
}

export default App;
