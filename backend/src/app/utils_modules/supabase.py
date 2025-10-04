# Import the supabse creds from the config
from ..core.config import settings
from supabase import create_client, Client

# Create a function to return supabase client
def get_client() -> Client:
    supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
    return supabase