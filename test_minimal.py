import app

table_request = "Table shell: please include age and gender."

API_KEY = "AIzaSyC68FbkIkGkgeZzdDtEiYuhgROfENZTnxM"
output_yaml_name = "gemini_test_table_2.yaml"

print("Sending request to Gemini...\n")
yaml_path = app.generate_yaml(API_KEY, table_request, output_yaml_name)

print("=== OUTPUT ===")
print(f"File saved to: {yaml_path}")
with open(yaml_path, "r") as f:
    print(f.read())
print("=============")
