# Running the MultiServ Setup Script

This document provides two methods for running the `setup.sh` script to configure your MultiServ restreaming server.

---

## Method 1: The One-Liner (Direct Execution)

This method downloads the script and executes it in a single command. It is fast but requires you to fully trust the source of the script, as you are running it with root privileges without reviewing it first.

### Command

Execute the following command on your server:

```bash
curl -sSL https://raw.githubusercontent.com/Makeea/MultiServ/main/script/setup.sh | sudo bash
```

### How It Works

*   `curl -sSL [URL]`: Fetches the script content from the GitHub repository.
*   `|`: The "pipe" operator sends the script content directly to the next command.
*   `sudo bash`: Executes the script content with root (`sudo`) privileges using the `bash` interpreter.

> **Security Warning:** This method is powerful but potentially dangerous. You are giving administrative access to your system to a script downloaded directly from the internet. Only use this method if you have verified the script's source and content.

---

## Method 2: The Safer, Recommended Way (Download and Inspect)

This is the recommended approach for any production or security-conscious environment. It involves downloading the script, reviewing its contents to ensure it's safe, and then executing it locally.

### Step 1: Download the Script

Use `curl` to save the script to a local file named `setup.sh`.

```bash
curl -o setup.sh https://raw.githubusercontent.com/Makeea/MultiServ/main/script/setup.sh
```

### Step 2: Inspect the Script (Crucial)

Before running it, open the file and read its contents to understand exactly what it will do.

```bash
less setup.sh
```
*(Press `q` to exit the `less` viewer.)*

### Step 3: Make the Script Executable

Grant the script execute permissions.

```bash
chmod +x setup.sh
```

### Step 4: Run the Script

Execute the script with `sudo` privileges.

```bash
sudo ./setup.sh
```

This two-step process gives you full control and ensures you are not running unknown or malicious code on your server.
