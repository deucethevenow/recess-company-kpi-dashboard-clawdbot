#!/bin/bash
# Start the Recess KPI Dashboard with BigQuery credentials

# Change to dashboard directory
cd "$(dirname "$0")"

# Set the Google Cloud credentials
export GOOGLE_APPLICATION_CREDENTIALS="/Users/deucethevenowworkm1/.config/bigquery-mcp-key.json"

# Activate virtual environment
source venv/bin/activate

# Kill any existing Streamlit process
pkill -f "streamlit run app.py" 2>/dev/null

# Start Streamlit
echo "🚀 Starting Recess KPI Dashboard..."
echo "📊 BigQuery credentials: $GOOGLE_APPLICATION_CREDENTIALS"
streamlit run app.py --server.port 8501
