# Godot AWS Client

A Godot game project with AWS backend integration using Cognito authentication, API Gateway, DynamoDB, and S3.

## Environment Configuration

This project uses a centralized `.env` file to manage environment variables for the Godot client.

### 📄 .env File Template

Create a `.env` file at the root of your project with the following template:

```bash
# ============================
# Godot Game Backend Settings
# ============================

# --- AWS region and stage ---
STAGE=dev
AWS_REGION=us-west-2

# --- Cognito configuration ---
COGNITO_USER_POOL_ID=us-west-2_XXXXXXX
COGNITO_APP_CLIENT_ID=XXXXXXXXXXXXXX
COGNITO_REGION=us-west-2

# --- API Gateway configuration ---
API_BASE_URL=https://api.yourdomain.com
API_STAGE=dev

# --- S3 catalog configuration ---
CATALOG_BUCKET=gg-catalog-1234567890-us-west-2-dev
CATALOG_VERSION=3

# --- Optional debug settings ---
LOG_LEVEL=debug
ENABLE_MOCK_DATA=false
```

### 🔧 Setup Instructions

#### 1. File Placement

Place the `.env` file at the root of your Godot project:

```
project_root/
├─ .env
├─ src/
├─ addons/
└─ project.godot
```

#### 2. Environment Variables Setup

The project includes an `Env` autoload singleton that automatically loads environment variables from the `.env` file.

#### 3. Usage in Godot Scripts

Access environment variables anywhere in your code:

```gdscript
# Get API configuration
var api_url = Env.get_var("API_BASE_URL")
var user_pool = Env.get_var("COGNITO_USER_POOL_ID")

# Example login implementation
func _on_login_pressed():
    var region = Env.get_var("COGNITO_REGION")
    var pool_id = Env.get_var("COGNITO_USER_POOL_ID")
    var client_id = Env.get_var("COGNITO_APP_CLIENT_ID")
    var api = Env.get_var("API_BASE_URL")
    
    print("Connecting to Cognito:", pool_id)
    # Your login logic using Cognito InitiateAuth here
```

#### 4. Multiple Environments

For different environments, use separate files:

- `.env.dev` - Development environment
- `.env.prod` - Production environment

Switch environments in your build script:

```bash
cp .env.dev .env
godot --headless --export-release "Linux/X11" build/game.x86_64
```


### 🔒 Security Notice

- **Do not store secrets** (access keys, passwords) in `.env` files
- Cognito IDs, API URLs, and region names are safe to include
- Real secrets should be stored in AWS SSM Parameter Store or Secrets Manager
- Add `.env` to your `.gitignore` file to prevent committing sensitive data
- You can safely commit a `.env.template` with placeholder values

### 📁 Project Structure

```
infrastructure/
├── cognito/
│   ├── samconfig.toml
│   └── template.yaml
```

The infrastructure folder contains AWS SAM templates for deploying the backend services.