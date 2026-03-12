import app

# 1. Simulate the uploaded file
with open("dummy_shell.txt", "r") as f:
    table_request = f.read()

# 2. Add your API Key (We'll use the one from generate_yaml_api.py temporarily)
API_KEY = "AIzaSyC68FbkIkGkgeZzdDtEiYuhgROfENZTnxM"

# 3. Choose your output name
output_yaml_name = "gemini_test_table.yaml"

# 4. Generate the YAML using the Streamlit app's internal logic
print("=== INPUT ===")
print(table_request)
print("=============\n")

print("Sending request to Gemini...\n")
yaml_path = app.generate_yaml(API_KEY, table_request, output_yaml_name)

print("=== OUTPUT ===")
print(f"File saved to: {yaml_path}")
with open(yaml_path, "r") as f:
    print(f.read())
print("=============")
