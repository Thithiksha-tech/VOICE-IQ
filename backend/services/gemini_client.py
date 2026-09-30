from google import genai

# Tried in order; later models are used only when an earlier one is overloaded
# (503) or rate limited (429), which happens often during peak demand.
GEMINI_MODELS = ["gemini-3.8-flash", "gemini-flash-lite-latest"]


def generate_with_fallback(client: genai.Client, **kwargs):
    """Calls generate_content, falling back to the next model on transient errors."""
    last_error = None
    for model in GEMINI_MODELS:
        try:
            return client.models.generate_content(model=model, **kwargs)
        except Exception as e:
            if not any(code in str(e) for code in ("503", "429", "UNAVAILABLE", "RESOURCE_EXHAUSTED")):
                raise
            print(f"[Gemini] {model} unavailable, trying next model: {str(e)[:120]}")
            last_error = e
    raise last_error
