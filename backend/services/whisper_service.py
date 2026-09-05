import os
import base64
from typing import Tuple
from dotenv import load_dotenv

load_dotenv()

class AudioTranscriptionService:
    """Service to handle speech-to-text transcription using real AI APIs."""

    def __init__(self):
        self.gemini_key = os.getenv("GEMINI_API_KEY")
        self.openai_key = os.getenv("OPENAI_API_KEY")

    async def transcribe_audio(self, audio_file_path: str) -> str:
        """
        Transcribes the uploaded audio file into plain text using Gemini or OpenAI Whisper.
        Returns the clean transcript string or raises a meaningful exception.
        """
        if not os.path.exists(audio_file_path):
            raise FileNotFoundError(f"Audio file not found at {audio_file_path}")

        file_size = os.path.getsize(audio_file_path)
        if file_size < 1000:
            # File is smaller than 1KB, likely an empty audio capture
            raise ValueError("Audio recording is empty or too short. Please speak clearly into the microphone.")

        # Preferred: Gemini GenAI SDK
        if self.gemini_key:
            try:
                from google import genai
                from google.genai import types

                client = genai.Client(api_key=self.gemini_key)
                
                with open(audio_file_path, "rb") as f:
                    audio_bytes = f.read()

                # Determine mime type
                mime_type = "audio/wav"
                if audio_file_path.endswith(".mp3"):
                    mime_type = "audio/mp3"
                elif audio_file_path.endswith(".m4a"):
                    mime_type = "audio/mp4"
                elif audio_file_path.endswith(".aac"):
                    mime_type = "audio/aac"
                elif audio_file_path.endswith(".webm"):
                    mime_type = "audio/webm"

                response = client.models.generate_content(
                    model="gemini-3.5-transcribe",
                    contents=[
                        types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
                        "Accurately transcribe all words spoken in this audio. Do not summarize or add commentary. Return only the spoken transcript. If there is no audible speech, return EMPTY_AUDIO."
                    ]
                )

                transcript = response.text.strip() if response.text else ""
                if not transcript or transcript == "EMPTY_AUDIO" or "no audible speech" in transcript.lower():
                    raise ValueError("No speech could be detected in your recording. Please check your microphone and try speaking again.")

                return transcript

            except Exception as e:
                # If Gemini transcribe fails, try fallback or raise clean error
                if "No speech could be detected" in str(e):
                    raise
                print(f"[Transcription Warning] Gemini transcription error: {e}")

        # Alternative: OpenAI Whisper API
        if self.openai_key:
            try:
                from openai import OpenAI
                client = OpenAI(api_key=self.openai_key)
                with open(audio_file_path, "rb") as audio_file:
                    res = client.audio.transcriptions.create(
                        model="whisper-1",
                        file=audio_file,
                        response_format="text"
                    )
                transcript = res.strip() if isinstance(res, str) else res.text.strip()
                if not transcript:
                    raise ValueError("No speech could be detected in your recording.")
                return transcript
            except Exception as e:
                if "No speech could be detected" in str(e):
                    raise
                print(f"[Transcription Warning] OpenAI Whisper error: {e}")

        # If neither key is present or both failed on API connection, raise actionable guidance
        raise RuntimeError("Speech-to-text service is unavailable. Please ensure GEMINI_API_KEY or OPENAI_API_KEY is configured in backend/.env.")

transcription_service = AudioTranscriptionService()
