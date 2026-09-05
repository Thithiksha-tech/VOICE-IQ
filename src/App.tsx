import React, { useState, useEffect, useRef } from "react";
import {
  Mic,
  Square,
  Play,
  Pause,
  RotateCcw,
  Send,
  Award,
  BookOpen,
  TrendingUp,
  UserCheck,
  ShieldCheck,
  Activity,
  CheckCircle2,
  ChevronRight,
  LogOut,
  Sparkles,
  Volume2,
  FileCode2,
  Laptop,
  Smartphone,
  Server,
  Database,
  ArrowRight,
  HelpCircle,
  Clock,
  Layers
} from "lucide-react";

interface User {
  user_id: number;
  name: string;
  email: string;
  role: "student" | "admin";
  access_token: string;
}

interface SpeechAnalysis {
  id: number;
  practice_session_id: number;
  fluency_score: number;
  pronunciation_score: number;
  grammar_score: number;
  vocabulary_score: number;
  confidence_score: number;
  words_per_minute: number;
  filler_word_count: number;
  feedback: string;
  created_at: string;
}

interface PracticeSession {
  id: number;
  student_id: number;
  prompt: string;
  transcript?: string;
  overall_score?: number;
  created_at: string;
  analysis?: SpeechAnalysis;
}

interface StudentDashboardData {
  student_id: number;
  student_name: string;
  student_email: string;
  overall_performance: number;
  practice_sessions_count: number;
  recent_score: number | null;
  recent_sessions: PracticeSession[];
}

interface AdminDashboardData {
  total_students: number;
  total_practice_sessions: number;
  average_performance: number;
  recent_activity: {
    session_id: number;
    student_id: number;
    student_name: string;
    prompt: string;
    overall_score: number;
    created_at: string;
  }[];
}

interface AdminStudentSummary {
  id: number;
  name: string;
  email: string;
  sessions_count: number;
  average_score: number;
}

const DEFAULT_PROMPTS = [
  "Tell me about yourself, your academic background, and your MCA final-year project.",
  "What is the difference between synchronous and asynchronous communication in distributed systems?",
  "Explain the significance of database indexing and how B-trees optimize query execution.",
  "How do you handle challenging conflicts within an agile software engineering team?",
  "Describe the architectural differences between monolithic and microservices paradigms."
];

export function App() {
  // Navigation & Mode
  const [activePortal, setActivePortal] = useState<"student" | "admin" | "docs">("student");
  const [studentTab, setStudentTab] = useState<"dashboard" | "practice" | "history" | "progress">("dashboard");

  // Auth State
  const [user, setUser] = useState<User | null>(() => {
    return {
      user_id: 2,
      name: "Rahul Sharma",
      email: "student@voiceiq.edu",
      role: "student",
      access_token: btoa(JSON.stringify({ id: 2, role: "student", email: "student@voiceiq.edu" })),
    };
  });
  const [adminUser, setAdminUser] = useState<User | null>(() => {
    return {
      user_id: 1,
      name: "MCA Faculty Evaluator",
      email: "admin@voiceiq.edu",
      role: "admin",
      access_token: btoa(JSON.stringify({ id: 1, role: "admin", email: "admin@voiceiq.edu" })),
    };
  });

  // Login form state
  const [loginEmail, setLoginEmail] = useState("student@voiceiq.edu");
  const [loginPassword, setLoginPassword] = useState("Student@12345");
  const [registerName, setRegisterName] = useState("");
  const [isRegistering, setIsRegistering] = useState(false);
  const [adminLoginEmail, setAdminLoginEmail] = useState("admin@voiceiq.edu");
  const [adminLoginPassword, setAdminLoginPassword] = useState("Admin@12345");
  const [authError, setAuthError] = useState<string | null>(null);

  // Student Data
  const [dashboardData, setDashboardData] = useState<StudentDashboardData | null>(null);
  const [historyList, setHistoryList] = useState<PracticeSession[]>([]);
  const [selectedSession, setSelectedSession] = useState<PracticeSession | null>(null);

  // Audio Recording State
  const [selectedPromptIndex, setSelectedPromptIndex] = useState(0);
  const [isRecording, setIsRecording] = useState(false);
  const [recordingSeconds, setRecordingSeconds] = useState(0);
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisStatus, setAnalysisStatus] = useState("");

  // Admin Data
  const [adminDashboard, setAdminDashboard] = useState<AdminDashboardData | null>(null);
  const [adminStudents, setAdminStudents] = useState<AdminStudentSummary[]>([]);
  const [inspectedStudent, setInspectedStudent] = useState<AdminStudentSummary | null>(null);
  const [inspectedStudentHistory, setInspectedStudentHistory] = useState<PracticeSession[]>([]);

  // Refs
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<number | null>(null);
  const audioElementRef = useRef<HTMLAudioElement | null>(null);

  // Fetch Student Dashboard
  const fetchStudentData = async () => {
    if (!user) return;
    try {
      const res = await fetch("/api/history/dashboard/student", {
        headers: { Authorization: `Bearer ${user.access_token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setDashboardData(data);
      }

      const histRes = await fetch(`/api/history/student/${user.user_id}`, {
        headers: { Authorization: `Bearer ${user.access_token}` },
      });
      if (histRes.ok) {
        const histData = await histRes.json();
        setHistoryList(histData);
      }
    } catch (e) {
      console.error("Error loading student data:", e);
    }
  };

  // Fetch Admin Data
  const fetchAdminData = async () => {
    if (!adminUser) return;
    try {
      const res = await fetch("/api/admin/dashboard", {
        headers: { Authorization: `Bearer ${adminUser.access_token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setAdminDashboard(data);
      }

      const studRes = await fetch("/api/admin/students", {
        headers: { Authorization: `Bearer ${adminUser.access_token}` },
      });
      if (studRes.ok) {
        const studData = await studRes.json();
        setAdminStudents(studData);
      }
    } catch (e) {
      console.error("Error loading admin data:", e);
    }
  };

  useEffect(() => {
    fetchStudentData();
    fetchAdminData();
  }, [user, adminUser]);

  // Handle Recording
  const startRecording = async () => {
    try {
      setAudioBlob(null);
      setAudioUrl(null);
      audioChunksRef.current = [];

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(audioChunksRef.current, { type: "audio/webm" });
        setAudioBlob(blob);
        const url = URL.createObjectURL(blob);
        setAudioUrl(url);
        stream.getTracks().forEach((track) => track.stop());
      };

      mediaRecorder.start();
      setIsRecording(true);
      setRecordingSeconds(0);

      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = window.setInterval(() => {
        setRecordingSeconds((prev) => prev + 1);
      }, 1000);
    } catch (err) {
      alert("Microphone permission was denied or is not supported in this browser. Please allow microphone access.");
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    }
  };

  const togglePlayback = () => {
    if (!audioElementRef.current && audioUrl) {
      const audio = new Audio(audioUrl);
      audioElementRef.current = audio;
      audio.onended = () => setIsPlaying(false);
      audio.play();
      setIsPlaying(true);
    } else if (audioElementRef.current) {
      if (isPlaying) {
        audioElementRef.current.pause();
        setIsPlaying(false);
      } else {
        audioElementRef.current.play();
        setIsPlaying(true);
      }
    }
  };

  const submitRecording = async () => {
    if (!audioBlob || !user) return;

    setIsAnalyzing(true);
    setAnalysisStatus("Uploading voice recording to server...");

    try {
      const formData = new FormData();
      formData.append("audio", audioBlob, "user_recording.webm");
      formData.append("prompt", DEFAULT_PROMPTS[selectedPromptIndex]);
      formData.append("duration", recordingSeconds.toString());

      setAnalysisStatus("Gemini AI Speech Transcription & 7-Metric Evaluation in progress...");

      const response = await fetch("/api/audio/analyze", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${user.access_token}`,
        },
        body: formData,
      });

      if (!response.ok) {
        throw new Error("Failed to analyze voice recording.");
      }

      const result: PracticeSession = await response.json();
      setSelectedSession(result);
      setIsAnalyzing(false);
      setAudioBlob(null);
      setAudioUrl(null);
      fetchStudentData();
      fetchAdminData();
    } catch (err: any) {
      alert(err.message || "Analysis failed.");
      setIsAnalyzing(false);
    }
  };

  // Inspect student in admin
  const inspectStudent = async (student: AdminStudentSummary) => {
    setInspectedStudent(student);
    if (!adminUser) return;
    try {
      const res = await fetch(`/api/history/student/${student.id}`, {
        headers: { Authorization: `Bearer ${adminUser.access_token}` },
      });
      if (res.ok) {
        const hist = await res.json();
        setInspectedStudentHistory(hist);
      }
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 flex flex-col font-sans">
      {/* Top Application Bar */}
      <header className="bg-slate-900 text-white border-b border-slate-800 sticky top-0 z-30 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center text-white shadow-md shadow-blue-500/30">
              <Mic className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-bold text-lg tracking-tight text-white">VoiceIQ</span>
                <span className="text-xs bg-blue-500/20 text-blue-300 font-semibold px-2 py-0.5 rounded-full border border-blue-400/30">
                  MCA Capstone
                </span>
              </div>
              <p className="text-xs text-slate-400 hidden sm:block">AI-Powered Voice Communication Practice & Speech Analysis</p>
            </div>
          </div>

          {/* Portal Switcher Tabs */}
          <div className="flex items-center bg-slate-800/90 p-1 rounded-xl border border-slate-700/60">
            <button
              onClick={() => setActivePortal("student")}
              className={`flex items-center space-x-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                activePortal === "student"
                  ? "bg-blue-600 text-white shadow"
                  : "text-slate-300 hover:text-white"
              }`}
            >
              <Smartphone className="w-3.5 h-3.5" />
              <span>Student Mobile Portal</span>
            </button>
            <button
              onClick={() => setActivePortal("admin")}
              className={`flex items-center space-x-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                activePortal === "admin"
                  ? "bg-amber-500 text-slate-950 font-bold shadow"
                  : "text-slate-300 hover:text-white"
              }`}
            >
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Admin / Faculty Console</span>
            </button>
            <button
              onClick={() => setActivePortal("docs")}
              className={`flex items-center space-x-2 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                activePortal === "docs"
                  ? "bg-slate-700 text-white shadow"
                  : "text-slate-400 hover:text-white"
              }`}
            >
              <FileCode2 className="w-3.5 h-3.5" />
              <span>Project & Viva Guide</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6">
        {/* ======================= PORTAL 1: STUDENT MOBILE PRODUCT ======================= */}
        {activePortal === "student" && (
          <div>
            {!user ? (
              // Student Login / Register Form
              <div className="max-w-md mx-auto my-12 bg-white rounded-2xl shadow-sm border border-slate-200 p-8">
                <div className="text-center mb-6">
                  <div className="w-14 h-14 bg-blue-50 text-blue-600 rounded-2xl flex items-center justify-center mx-auto mb-3">
                    <Mic className="w-7 h-7" />
                  </div>
                  <h2 className="text-2xl font-bold text-slate-900">Student Sign In</h2>
                  <p className="text-sm text-slate-500 mt-1">Access your speech analysis dashboard and practice viva questions.</p>
                </div>

                {authError && (
                  <div className="p-3 mb-4 rounded-xl bg-red-50 border border-red-200 text-red-700 text-xs">
                    {authError}
                  </div>
                )}

                <div className="space-y-4">
                  {isRegistering && (
                    <div>
                      <label className="block text-xs font-semibold text-slate-600 mb-1">Full Name</label>
                      <input
                        type="text"
                        value={registerName}
                        onChange={(e) => setRegisterName(e.target.value)}
                        placeholder="e.g. Rahul Sharma"
                        className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                  )}

                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">College Email Address</label>
                    <input
                      type="email"
                      value={loginEmail}
                      onChange={(e) => setLoginEmail(e.target.value)}
                      placeholder="student@voiceiq.edu"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-600 mb-1">Password</label>
                    <input
                      type="password"
                      value={loginPassword}
                      onChange={(e) => setLoginPassword(e.target.value)}
                      placeholder="••••••••"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  <button
                    onClick={async () => {
                      setAuthError(null);
                      try {
                        const url = isRegistering ? "/api/auth/register" : "/api/auth/login";
                        const payload = isRegistering
                          ? { name: registerName, email: loginEmail, password: loginPassword }
                          : { email: loginEmail, password: loginPassword };
                        const res = await fetch(url, {
                          method: "POST",
                          headers: { "Content-Type": "application/json" },
                          body: JSON.stringify(payload),
                        });
                        const data = await res.json();
                        if (res.ok) {
                          setUser(data);
                        } else {
                          setAuthError(data.detail || "Authentication failed.");
                        }
                      } catch (err: any) {
                        setAuthError(err.message || "Network error");
                      }
                    }}
                    className="w-full py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold text-sm rounded-xl shadow transition-colors"
                  >
                    {isRegistering ? "Create Student Account" : "Sign In to Practice"}
                  </button>

                  <div className="text-center pt-2">
                    <button
                      onClick={() => {
                        setIsRegistering(!isRegistering);
                        setAuthError(null);
                      }}
                      className="text-xs text-blue-600 hover:underline font-medium"
                    >
                      {isRegistering ? "Already have an account? Sign in" : "New student? Create an account"}
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              // Authenticated Student App Shell
              <div>
                {/* Student Sub-Header Navigation */}
                <div className="bg-white rounded-2xl border border-slate-200/80 p-4 mb-6 flex flex-wrap items-center justify-between gap-4 shadow-sm">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center font-bold text-sm">
                      {user.name[0]}
                    </div>
                    <div>
                      <h3 className="font-bold text-slate-900 leading-tight">{user.name}</h3>
                      <p className="text-xs text-slate-500">{user.email}</p>
                    </div>
                  </div>

                  {/* Tab Navigation */}
                  <div className="flex space-x-1 bg-slate-100 p-1 rounded-xl">
                    <button
                      onClick={() => {
                        setStudentTab("dashboard");
                        setSelectedSession(null);
                      }}
                      className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                        studentTab === "dashboard" && !selectedSession ? "bg-white text-blue-600 shadow-sm" : "text-slate-600 hover:text-slate-900"
                      }`}
                    >
                      Dashboard
                    </button>
                    <button
                      onClick={() => {
                        setStudentTab("practice");
                        setSelectedSession(null);
                      }}
                      className={`flex items-center space-x-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                        studentTab === "practice" && !selectedSession ? "bg-blue-600 text-white shadow-sm" : "text-slate-600 hover:text-slate-900"
                      }`}
                    >
                      <Mic className="w-3.5 h-3.5" />
                      <span>Start Practice</span>
                    </button>
                    <button
                      onClick={() => {
                        setStudentTab("history");
                        setSelectedSession(null);
                      }}
                      className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                        studentTab === "history" && !selectedSession ? "bg-white text-blue-600 shadow-sm" : "text-slate-600 hover:text-slate-900"
                      }`}
                    >
                      History ({historyList.length})
                    </button>
                    <button
                      onClick={() => {
                        setStudentTab("progress");
                        setSelectedSession(null);
                      }}
                      className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                        studentTab === "progress" && !selectedSession ? "bg-white text-blue-600 shadow-sm" : "text-slate-600 hover:text-slate-900"
                      }`}
                    >
                      Analytics
                    </button>
                  </div>

                  <button
                    onClick={() => setUser(null)}
                    className="flex items-center space-x-1 text-xs text-slate-500 hover:text-red-600 px-3 py-1.5 rounded-lg hover:bg-red-50 transition"
                  >
                    <LogOut className="w-3.5 h-3.5" />
                    <span>Sign Out</span>
                  </button>
                </div>

                {/* --- DETAILED ANALYSIS RESULT VIEW --- */}
                {selectedSession ? (
                  <div className="space-y-6">
                    <button
                      onClick={() => setSelectedSession(null)}
                      className="inline-flex items-center text-xs font-semibold text-blue-600 hover:underline mb-2"
                    >
                      ← Back to {studentTab === "history" ? "History List" : "Dashboard"}
                    </button>

                    {/* Overall Score Banner */}
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 sm:p-8 shadow-sm">
                      <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
                        <div className="flex items-center space-x-6">
                          <div className="relative w-24 h-24 rounded-full border-4 border-emerald-500 flex flex-col items-center justify-center bg-emerald-50 text-emerald-700">
                            <span className="text-3xl font-black">{selectedSession.overall_score?.toFixed(0) || "—"}</span>
                            <span className="text-[10px] font-bold tracking-wider uppercase">Score</span>
                          </div>
                          <div>
                            <span className="text-xs font-bold text-emerald-600 bg-emerald-100 px-2.5 py-1 rounded-full uppercase tracking-wider">
                              AI Speech Evaluation Completed
                            </span>
                            <h2 className="text-xl font-bold text-slate-900 mt-2">Overall Communication Performance</h2>
                            <p className="text-xs text-slate-500 mt-0.5">
                              Recorded on {new Date(selectedSession.created_at).toLocaleString()}
                            </p>
                          </div>
                        </div>

                        <div className="flex gap-4 border-t sm:border-t-0 sm:border-l border-slate-200 pt-4 sm:pt-0 sm:pl-6 w-full sm:w-auto justify-around">
                          <div className="text-center">
                            <span className="text-xs text-slate-500 block">Speaking Pace</span>
                            <span className="text-lg font-bold text-slate-900">
                              {selectedSession.analysis?.words_per_minute.toFixed(0)} WPM
                            </span>
                            <span className="text-[10px] text-emerald-600 block">Target: 120-150</span>
                          </div>
                          <div className="text-center">
                            <span className="text-xs text-slate-500 block">Filler Words</span>
                            <span className="text-lg font-bold text-slate-900">
                              {selectedSession.analysis?.filler_word_count ?? 0}
                            </span>
                            <span className="text-[10px] text-slate-400 block">um, like, etc.</span>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* 5 Core Metrics Grid */}
                    {selectedSession.analysis && (
                      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
                        <h3 className="text-base font-bold text-slate-900 mb-4">Core Competency Breakdown</h3>
                        <div className="space-y-4">
                          {[
                            { label: "Fluency & Speech Rhythm", score: selectedSession.analysis.fluency_score, icon: "🌊" },
                            { label: "Pronunciation Clarity (AI-Estimated)", score: selectedSession.analysis.pronunciation_score, icon: "🗣️" },
                            { label: "Grammar & Syntactic Accuracy", score: selectedSession.analysis.grammar_score, icon: "✍️" },
                            { label: "Vocabulary & Lexical Richness", score: selectedSession.analysis.vocabulary_score, icon: "📖" },
                            { label: "Confidence & Delivery Index", score: selectedSession.analysis.confidence_score, icon: "🛡️" },
                          ].map((item, idx) => (
                            <div key={idx} className="space-y-1">
                              <div className="flex justify-between text-xs font-semibold">
                                <span className="text-slate-700 flex items-center gap-1.5">
                                  <span>{item.icon}</span> {item.label}
                                </span>
                                <span className="text-slate-900 font-bold">{item.score.toFixed(0)} / 100</span>
                              </div>
                              <div className="w-full bg-slate-100 rounded-full h-2.5 overflow-hidden">
                                <div
                                  className={`h-full rounded-full ${
                                    item.score >= 80 ? "bg-emerald-500" : item.score >= 65 ? "bg-blue-500" : "bg-amber-500"
                                  }`}
                                  style={{ width: `${item.score}%` }}
                                />
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Spoken Transcript Card */}
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
                      <div className="flex items-center space-x-2 mb-3">
                        <Volume2 className="w-5 h-5 text-blue-600" />
                        <h3 className="text-base font-bold text-slate-900">Spoken Transcript</h3>
                      </div>
                      <p className="text-xs text-slate-500 font-medium mb-3">Prompt: &ldquo;{selectedSession.prompt}&rdquo;</p>
                      <div className="bg-slate-50 rounded-xl p-4 text-sm text-slate-800 leading-relaxed border border-slate-200">
                        {selectedSession.transcript || "No transcript available"}
                      </div>
                    </div>

                    {/* AI Feedback & Action Plan */}
                    {selectedSession.analysis && (
                      <div className="bg-emerald-50/70 border border-emerald-200/80 rounded-2xl p-6">
                        <div className="flex items-center space-x-2 text-emerald-900 font-bold text-base mb-2">
                          <Sparkles className="w-5 h-5 text-emerald-600" />
                          <span>AI Feedback & Placement Improvement Tips</span>
                        </div>
                        <p className="text-sm text-emerald-950 leading-relaxed font-medium">
                          {selectedSession.analysis.feedback}
                        </p>
                      </div>
                    )}

                    <div className="flex justify-end space-x-3 pt-2">
                      <button
                        onClick={() => {
                          setSelectedSession(null);
                          setStudentTab("practice");
                        }}
                        className="px-5 py-2.5 bg-blue-600 text-white font-semibold text-xs rounded-xl shadow hover:bg-blue-700 transition"
                      >
                        Practice Next Prompt
                      </button>
                    </div>
                  </div>
                ) : studentTab === "practice" ? (
                  // --- PRACTICE & VOICE RECORDING STUDIO ---
                  <div className="max-w-2xl mx-auto space-y-6">
                    {/* Prompt Selection Card */}
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
                      <div className="flex items-center justify-between mb-3">
                        <span className="text-xs font-bold text-blue-600 bg-blue-50 px-2.5 py-1 rounded-full uppercase tracking-wider">
                          Viva & Placement Prompt
                        </span>
                        <button
                          onClick={() => setSelectedPromptIndex((prev) => (prev + 1) % DEFAULT_PROMPTS.length)}
                          className="text-xs font-semibold text-slate-500 hover:text-blue-600 flex items-center gap-1"
                        >
                          <RotateCcw className="w-3.5 h-3.5" /> Next Question
                        </button>
                      </div>
                      <h3 className="text-lg font-bold text-slate-900 leading-relaxed">
                        {DEFAULT_PROMPTS[selectedPromptIndex]}
                      </h3>
                      <p className="text-xs text-slate-400 mt-2">
                        Guideline: Explain your response clearly in structured sentences. Aim for 20-45 seconds of speech.
                      </p>
                    </div>

                    {/* Microphone Recording Controller */}
                    <div className="bg-white rounded-2xl border border-slate-200 p-8 shadow-sm text-center">
                      <div className="my-6">
                        <button
                          disabled={isAnalyzing}
                          onClick={isRecording ? stopRecording : startRecording}
                          className={`w-28 h-28 rounded-full flex flex-col items-center justify-center mx-auto transition-all shadow-lg ${
                            isRecording
                              ? "bg-red-500 hover:bg-red-600 text-white animate-pulse shadow-red-500/30"
                              : audioBlob
                              ? "bg-emerald-600 hover:bg-emerald-700 text-white shadow-emerald-600/30"
                              : "bg-blue-600 hover:bg-blue-700 text-white shadow-blue-600/30"
                          }`}
                        >
                          {isRecording ? (
                            <>
                              <Square className="w-8 h-8 fill-current" />
                              <span className="text-[11px] font-bold mt-1">STOP</span>
                            </>
                          ) : (
                            <>
                              <Mic className="w-8 h-8" />
                              <span className="text-[11px] font-bold mt-1">
                                {audioBlob ? "RE-RECORD" : "RECORD"}
                              </span>
                            </>
                          )}
                        </button>
                      </div>

                      {/* Timer & State */}
                      <div className="space-y-1">
                        <div className="text-2xl font-black text-slate-800 tracking-tight">
                          {Math.floor(recordingSeconds / 60)}:
                          {(recordingSeconds % 60).toString().padStart(2, "0")}
                        </div>
                        <p className="text-xs text-slate-500">
                          {isRecording
                            ? "Microphone is active — speak your answer clearly..."
                            : audioBlob
                            ? "Recording ready! Listen to verify or submit for AI analysis."
                            : "Click the microphone button to start recording your answer."}
                        </p>
                      </div>

                      {/* Playback Control Bar (When recording exists) */}
                      {audioBlob && !isRecording && (
                        <div className="mt-6 p-4 bg-slate-50 rounded-xl border border-slate-200 flex items-center justify-between max-w-md mx-auto">
                          <div className="flex items-center space-x-3">
                            <button
                              onClick={togglePlayback}
                              className="w-10 h-10 rounded-full bg-blue-600 hover:bg-blue-700 text-white flex items-center justify-center shadow"
                            >
                              {isPlaying ? <Pause className="w-4 h-4 fill-current" /> : <Play className="w-4 h-4 fill-current ml-0.5" />}
                            </button>
                            <div className="text-left">
                              <span className="text-xs font-bold text-slate-800 block">Actual Recorded Audio</span>
                              <span className="text-[11px] text-slate-500">Review before AI speech-to-text</span>
                            </div>
                          </div>

                          <button
                            onClick={() => {
                              setAudioBlob(null);
                              setAudioUrl(null);
                              setRecordingSeconds(0);
                            }}
                            className="text-xs text-red-600 hover:underline font-semibold"
                          >
                            Discard
                          </button>
                        </div>
                      )}

                      {/* Analysis Processing Status */}
                      {isAnalyzing && (
                        <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-xl max-w-md mx-auto">
                          <div className="flex items-center justify-center space-x-3">
                            <div className="w-5 h-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin" />
                            <span className="text-xs font-bold text-blue-700">{analysisStatus}</span>
                          </div>
                        </div>
                      )}

                      {/* Submit Action */}
                      {audioBlob && !isRecording && !isAnalyzing && (
                        <div className="mt-6">
                          <button
                            onClick={submitRecording}
                            className="px-8 py-3.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm rounded-xl shadow-md transition-all flex items-center space-x-2 mx-auto"
                          >
                            <Sparkles className="w-4 h-4" />
                            <span>Analyze My Speech with AI</span>
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                ) : studentTab === "history" ? (
                  // --- PRACTICE HISTORY ---
                  <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
                    <h3 className="text-lg font-bold text-slate-900 mb-1">Previous Practice Sessions</h3>
                    <p className="text-xs text-slate-500 mb-6">Historical record of viva prompts, scores, and speech analysis results.</p>

                    {historyList.length === 0 ? (
                      <div className="text-center py-12 text-slate-400">
                        <Mic className="w-10 h-10 mx-auto mb-2 text-slate-300" />
                        <p className="text-sm font-semibold text-slate-600">No practice sessions logged yet</p>
                        <p className="text-xs text-slate-400 mt-1">Start your first speaking practice to generate history.</p>
                      </div>
                    ) : (
                      <div className="space-y-3">
                        {historyList.map((session) => (
                          <div
                            key={session.id}
                            onClick={() => setSelectedSession(session)}
                            className="p-4 rounded-xl border border-slate-200 hover:border-blue-300 hover:bg-blue-50/30 cursor-pointer transition flex items-center justify-between"
                          >
                            <div className="flex items-center space-x-4">
                              <div className="w-12 h-12 rounded-xl bg-slate-100 flex items-center justify-center font-black text-sm text-slate-800 border border-slate-200">
                                {session.overall_score?.toFixed(0) || "—"}
                              </div>
                              <div>
                                <h4 className="font-semibold text-sm text-slate-900 line-clamp-1">{session.prompt}</h4>
                                <span className="text-xs text-slate-400">
                                  {new Date(session.created_at).toLocaleDateString()} at{" "}
                                  {new Date(session.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                                </span>
                              </div>
                            </div>
                            <ChevronRight className="w-4 h-4 text-slate-400" />
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                ) : studentTab === "progress" ? (
                  // --- ANALYTICS / PROGRESS SCREEN ---
                  <div className="space-y-6">
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
                        <span className="text-xs font-semibold text-slate-400">Overall Proficiency</span>
                        <div className="text-3xl font-black text-slate-900 mt-1">
                          {dashboardData?.overall_performance.toFixed(1) || "0.0"}%
                        </div>
                        <span className="text-xs text-emerald-600 font-medium">Mean across all sessions</span>
                      </div>
                      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
                        <span className="text-xs font-semibold text-slate-400">Total Practice Sessions</span>
                        <div className="text-3xl font-black text-blue-600 mt-1">
                          {dashboardData?.practice_sessions_count || 0}
                        </div>
                        <span className="text-xs text-slate-500 font-medium">Recorded oral attempts</span>
                      </div>
                      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
                        <span className="text-xs font-semibold text-slate-400">Most Recent Score</span>
                        <div className="text-3xl font-black text-emerald-600 mt-1">
                          {dashboardData?.recent_score?.toFixed(0) || "—"}
                        </div>
                        <span className="text-xs text-slate-500 font-medium">Latest viva submission</span>
                      </div>
                    </div>

                    <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
                      <h3 className="text-base font-bold text-slate-900 mb-2">Longitudinal Session Progress</h3>
                      <p className="text-xs text-slate-500 mb-6">Score trajectory across completed speech evaluations</p>

                      <div className="h-48 flex items-end justify-between gap-2 pt-6 border-b border-slate-200 px-4">
                        {historyList.slice(0, 8).reverse().map((s, idx) => (
                          <div key={s.id} className="flex-1 flex flex-col items-center gap-2">
                            <span className="text-[11px] font-bold text-slate-700">{s.overall_score?.toFixed(0)}</span>
                            <div
                              className="w-full max-w-[40px] bg-blue-600 rounded-t-lg transition-all"
                              style={{ height: `${Math.max(16, ((s.overall_score || 0) / 100) * 140)}px` }}
                            />
                            <span className="text-[10px] text-slate-400">#{s.id}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                ) : (
                  // --- DEFAULT DASHBOARD HOME ---
                  <div className="space-y-6">
                    {/* Performance Summary Banner */}
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
                        <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Overall Performance</span>
                        <div className="text-3xl font-black text-slate-900 mt-1">
                          {dashboardData?.overall_performance.toFixed(1) || "0.0"}
                        </div>
                        <p className="text-xs text-slate-500 mt-1">Aggregated oral competency</p>
                      </div>

                      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
                        <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Practice Sessions</span>
                        <div className="text-3xl font-black text-blue-600 mt-1">
                          {dashboardData?.practice_sessions_count || 0}
                        </div>
                        <p className="text-xs text-slate-500 mt-1">Total recorded viva sessions</p>
                      </div>

                      <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
                        <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Recent Score</span>
                        <div className="text-3xl font-black text-emerald-600 mt-1">
                          {dashboardData?.recent_score?.toFixed(0) || "—"}
                        </div>
                        <p className="text-xs text-slate-500 mt-1">Latest evaluation result</p>
                      </div>
                    </div>

                    {/* Quick Call to Action */}
                    <div className="bg-gradient-to-r from-blue-700 to-indigo-800 rounded-2xl p-6 sm:p-8 text-white shadow-lg shadow-blue-700/10 flex flex-col sm:flex-row items-center justify-between gap-6">
                      <div className="space-y-2">
                        <span className="bg-blue-500/30 text-blue-200 text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wider">
                          Ready For Today&apos;s Viva Practice?
                        </span>
                        <h3 className="text-2xl font-bold">Practice Speech & Receive Instant AI Analysis</h3>
                        <p className="text-blue-100 text-xs sm:text-sm max-w-xl">
                          Record your voice against real viva prompts. VoiceIQ evaluates your speech pacing, pauses, vocabulary variety, grammatical syntax, and confidence.
                        </p>
                      </div>
                      <button
                        onClick={() => setStudentTab("practice")}
                        className="px-6 py-3.5 bg-white text-blue-900 hover:bg-blue-50 font-bold text-sm rounded-xl shadow-md transition flex items-center space-x-2 shrink-0"
                      >
                        <Mic className="w-4 h-4 text-blue-600" />
                        <span>Start Practice Session</span>
                      </button>
                    </div>

                    {/* Recent Sessions List */}
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
                      <div className="flex items-center justify-between mb-4">
                        <h3 className="text-base font-bold text-slate-900">Recent Practice Sessions</h3>
                        <button
                          onClick={() => setStudentTab("history")}
                          className="text-xs text-blue-600 font-semibold hover:underline"
                        >
                          View All
                        </button>
                      </div>

                      {dashboardData?.recent_sessions && dashboardData.recent_sessions.length > 0 ? (
                        <div className="space-y-3">
                          {dashboardData.recent_sessions.map((s) => (
                            <div
                              key={s.id}
                              onClick={() => setSelectedSession(s)}
                              className="p-4 rounded-xl border border-slate-100 bg-slate-50/50 hover:bg-blue-50/40 hover:border-blue-200 cursor-pointer transition flex items-center justify-between"
                            >
                              <div className="flex items-center space-x-4">
                                <div className="w-11 h-11 rounded-xl bg-white border border-slate-200 shadow-sm flex items-center justify-center font-bold text-slate-800">
                                  {s.overall_score?.toFixed(0) || "—"}
                                </div>
                                <div>
                                  <h4 className="font-semibold text-sm text-slate-900 line-clamp-1">{s.prompt}</h4>
                                  <span className="text-xs text-slate-400">
                                    {new Date(s.created_at).toLocaleDateString()}
                                  </span>
                                </div>
                              </div>
                              <ChevronRight className="w-4 h-4 text-slate-400" />
                            </div>
                          ))}
                        </div>
                      ) : (
                        <div className="text-center py-8 text-slate-400 text-xs">
                          No practice sessions completed yet. Click &ldquo;Start Practice Session&rdquo; above!
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* ======================= PORTAL 2: ADMIN & FACULTY CONSOLE ======================= */}
        {activePortal === "admin" && (
          <div className="space-y-6">
            <div className="bg-slate-900 text-white rounded-2xl p-6 border border-slate-800 shadow-lg">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div>
                  <div className="flex items-center space-x-2">
                    <ShieldCheck className="w-6 h-6 text-amber-400" />
                    <h2 className="text-xl font-bold">Faculty & Evaluator Administration Console</h2>
                  </div>
                  <p className="text-xs text-slate-400 mt-1">
                    Institutional oversight of MCA student cohorts, speech metrics, and viva evaluations.
                  </p>
                </div>
                <div className="text-xs text-slate-400">
                  Signed in as: <span className="text-amber-400 font-semibold">{adminUser?.name}</span>
                </div>
              </div>

              {/* KPI Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mt-6">
                <div className="bg-slate-800/80 rounded-xl p-4 border border-slate-700/60">
                  <span className="text-xs text-slate-400 uppercase tracking-wider font-semibold">Enrolled Students</span>
                  <div className="text-2xl font-black text-white mt-1">{adminDashboard?.total_students ?? 0}</div>
                  <span className="text-xs text-blue-400">Active student accounts</span>
                </div>
                <div className="bg-slate-800/80 rounded-xl p-4 border border-slate-700/60">
                  <span className="text-xs text-slate-400 uppercase tracking-wider font-semibold">Total Sessions Evaluated</span>
                  <div className="text-2xl font-black text-amber-400 mt-1">{adminDashboard?.total_practice_sessions ?? 0}</div>
                  <span className="text-xs text-slate-400">Audio recordings processed</span>
                </div>
                <div className="bg-slate-800/80 rounded-xl p-4 border border-slate-700/60">
                  <span className="text-xs text-slate-400 uppercase tracking-wider font-semibold">Institutional Average</span>
                  <div className="text-2xl font-black text-emerald-400 mt-1">{adminDashboard?.average_performance.toFixed(1) ?? "0.0"}%</div>
                  <span className="text-xs text-emerald-400">Cohort oral score</span>
                </div>
              </div>
            </div>

            {/* Admin Student Roster & Inspection */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Left Column: Student Roster */}
              <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm lg:col-span-1">
                <h3 className="text-base font-bold text-slate-900 mb-1">Student Roster</h3>
                <p className="text-xs text-slate-500 mb-4">Click any student to view detailed practice history</p>

                <div className="space-y-2">
                  {adminStudents.map((st) => (
                    <div
                      key={st.id}
                      onClick={() => inspectStudent(st)}
                      className={`p-3.5 rounded-xl border cursor-pointer transition ${
                        inspectedStudent?.id === st.id
                          ? "bg-amber-50 border-amber-300 shadow-sm"
                          : "border-slate-100 hover:bg-slate-50"
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <h4 className="font-semibold text-sm text-slate-900">{st.name}</h4>
                          <p className="text-xs text-slate-500">{st.email}</p>
                        </div>
                        <div className="text-right">
                          <span className="text-xs font-bold text-amber-600 block">{st.average_score.toFixed(0)}%</span>
                          <span className="text-[10px] text-slate-400">{st.sessions_count} sessions</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Right Column: Inspected Student Drill-down */}
              <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm lg:col-span-2">
                {inspectedStudent ? (
                  <div>
                    <div className="border-b border-slate-200 pb-4 mb-4 flex items-center justify-between">
                      <div>
                        <h3 className="text-lg font-bold text-slate-900">{inspectedStudent.name}</h3>
                        <p className="text-xs text-slate-500">Student ID #{inspectedStudent.id} • {inspectedStudent.email}</p>
                      </div>
                      <div className="text-right">
                        <span className="text-xs text-slate-400 block">Cohort Average</span>
                        <span className="text-xl font-bold text-amber-600">{inspectedStudent.average_score.toFixed(1)}%</span>
                      </div>
                    </div>

                    <h4 className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-3">
                      Submissions & Speech Evaluations ({inspectedStudentHistory.length})
                    </h4>

                    {inspectedStudentHistory.length === 0 ? (
                      <p className="text-xs text-slate-400 py-6 text-center">No submissions recorded for this student.</p>
                    ) : (
                      <div className="space-y-4">
                        {inspectedStudentHistory.map((s) => (
                          <div key={s.id} className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 space-y-3">
                            <div className="flex items-center justify-between">
                              <span className="text-xs font-bold text-slate-800">Prompt: {s.prompt}</span>
                              <span className="text-xs font-bold bg-amber-100 text-amber-800 px-2 py-0.5 rounded-full">
                                Score: {s.overall_score?.toFixed(0)}%
                              </span>
                            </div>
                            <p className="text-xs text-slate-600 bg-white p-3 rounded-lg border border-slate-100 italic">
                              &ldquo;{s.transcript}&rdquo;
                            </p>
                            {s.analysis && (
                              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-center text-xs">
                                <div className="bg-white p-2 rounded-lg border border-slate-100">
                                  <span className="text-slate-400 block text-[10px]">Fluency</span>
                                  <span className="font-bold text-slate-800">{s.analysis.fluency_score.toFixed(0)}%</span>
                                </div>
                                <div className="bg-white p-2 rounded-lg border border-slate-100">
                                  <span className="text-slate-400 block text-[10px]">Grammar</span>
                                  <span className="font-bold text-slate-800">{s.analysis.grammar_score.toFixed(0)}%</span>
                                </div>
                                <div className="bg-white p-2 rounded-lg border border-slate-100">
                                  <span className="text-slate-400 block text-[10px]">Confidence</span>
                                  <span className="font-bold text-slate-800">{s.analysis.confidence_score.toFixed(0)}%</span>
                                </div>
                                <div className="bg-white p-2 rounded-lg border border-slate-100">
                                  <span className="text-slate-400 block text-[10px]">Pacing</span>
                                  <span className="font-bold text-slate-800">{s.analysis.words_per_minute.toFixed(0)} WPM</span>
                                </div>
                              </div>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="text-center py-16 text-slate-400">
                    <UserCheck className="w-12 h-12 mx-auto mb-2 text-slate-300" />
                    <p className="text-sm font-semibold text-slate-700">Select a Student</p>
                    <p className="text-xs text-slate-400 mt-1">Choose a student from the roster to inspect individual evaluations.</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* ======================= PORTAL 3: PROJECT CODE & VIVA GUIDE ======================= */}
        {activePortal === "docs" && (
          <div className="space-y-6">
            <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
              <h2 className="text-xl font-bold text-slate-900">MCA Final-Year Project: Full Runnable Architecture</h2>
              <p className="text-xs text-slate-500 mt-1">
                Everything required to run, compile, install on physical Android phone, and defend in the MCA project viva.
              </p>

              {/* 3 Step Run Guide */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-6">
                <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
                  <div className="flex items-center space-x-2 text-blue-600 font-bold text-xs uppercase tracking-wider mb-2">
                    <Server className="w-4 h-4" />
                    <span>Step 1: Run Python Backend</span>
                  </div>
                  <pre className="bg-slate-900 text-slate-100 p-3 rounded-lg text-xs font-mono overflow-x-auto">
{`cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000`}
                  </pre>
                  <p className="text-xs text-slate-500 mt-2">
                    Binds to 0.0.0.0 so your physical phone can connect via local Wi-Fi.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
                  <div className="flex items-center space-x-2 text-emerald-600 font-bold text-xs uppercase tracking-wider mb-2">
                    <Smartphone className="w-4 h-4" />
                    <span>Step 2: Connect Phone</span>
                  </div>
                  <div className="bg-slate-900 text-slate-100 p-3 rounded-lg text-xs font-mono">
                    <span className="text-emerald-400">// In lib/utils/constants.dart</span>
                    <br />
                    apiBaseUrl = &quot;http://192.168.1.XX:8000&quot;
                  </div>
                  <p className="text-xs text-slate-500 mt-2">
                    Set your PC&apos;s Wi-Fi IP in constants.dart (or use 10.0.2.2 for Android Studio Emulator).
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
                  <div className="flex items-center space-x-2 text-purple-600 font-bold text-xs uppercase tracking-wider mb-2">
                    <Laptop className="w-4 h-4" />
                    <span>Step 3: Launch Flutter App</span>
                  </div>
                  <pre className="bg-slate-900 text-slate-100 p-3 rounded-lg text-xs font-mono overflow-x-auto">
{`flutter pub get
flutter run`}
                  </pre>
                  <p className="text-xs text-slate-500 mt-2">
                    Select your physical Android phone from the device list in Android Studio or terminal.
                  </p>
                </div>
              </div>
            </div>

            {/* MCA Viva Examination Questions & Answers */}
            <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4">
              <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
                <HelpCircle className="w-5 h-5 text-blue-600" />
                <span>Top MCA Viva Questions & Concise Examiner Answers</span>
              </h3>

              <div className="space-y-4 text-xs">
                <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                  <h4 className="font-bold text-slate-900 text-sm">
                    Q1: Why did you choose Flutter instead of native Android (Kotlin) or React Native?
                  </h4>
                  <p className="text-slate-600 leading-relaxed">
                    <strong>Answer:</strong> Flutter provides high-performance rendering via Skia/Impeller, ensuring smooth 60fps audio waveform animations and cross-platform compilation from a single Dart codebase. Its reactive state architecture with Provider cleanly decouples audio hardware services from presentation widgets.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                  <h4 className="font-bold text-slate-900 text-sm">
                    Q2: How does VoiceIQ secure API keys and prevent reverse engineering?
                  </h4>
                  <p className="text-slate-600 leading-relaxed">
                    <strong>Answer:</strong> Zero AI API keys are stored in the Flutter mobile application. The mobile client communicates exclusively with our Python FastAPI backend using JWT bearer tokens. All AI model orchestration (Gemini/Whisper) executes strictly server-side.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                  <h4 className="font-bold text-slate-900 text-sm">
                    Q3: How are the 7 speech metrics computed?
                  </h4>
                  <p className="text-slate-600 leading-relaxed">
                    <strong>Answer:</strong> Words Per Minute (WPM) and filler words (&ldquo;um&rdquo;, &ldquo;uh&rdquo;, &ldquo;like&rdquo;) are calculated through quantitative temporal NLP analysis. Fluency, pronunciation clarity, grammar accuracy, and confidence index are evaluated through Gemini AI structured JSON output prompting grounded against the specific prompt.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                  <h4 className="font-bold text-slate-900 text-sm">
                    Q4: How does physical Android phone networking operate during evaluation?
                  </h4>
                  <p className="text-slate-600 leading-relaxed">
                    <strong>Answer:</strong> Android physical devices cannot use &ldquo;localhost&rdquo; because localhost resolves to the phone itself. We bind Uvicorn to 0.0.0.0 and configure AppConstants.apiBaseUrl to the PC&apos;s local subnet IPv4 address (e.g. 192.168.1.15:8000) over shared Wi-Fi.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200 text-slate-500 py-4 px-6 text-xs text-center">
        VoiceIQ MCA Capstone Project • AI-Powered Voice Communication Practice & Speech Analysis System
      </footer>
    </div>
  );
}

export default App;
