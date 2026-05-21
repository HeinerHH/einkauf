import { signInWithPopup } from "firebase/auth";
import { auth, googleProvider } from "../firebase";

export default function Login() {
  return (
    <div className="login-screen">
      <div className="login-card">
        <div className="login-icon">{"\u{1F6D2}"}</div>
        <h1>Einkaufsliste</h1>
        <p>Einfach. Gemeinsam. Smart.</p>
        <button
          className="btn-google"
          onClick={() => signInWithPopup(auth, googleProvider)}
        >
          Mit Google anmelden
        </button>
        <p className="login-hint">
          Jeder meldet sich mit seinem eigenen Konto an.
          <br />
          Beim ersten Start Haushalt erstellen oder beitreten.
        </p>
      </div>
    </div>
  );
}
