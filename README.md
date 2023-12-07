# Origami Kernel Builder

This script is designed to automate the process of building an Android kernel, it streamlines various tasks involved in kernel compilation, such as configuration, compilation, and packaging.

## Features

- **Build Kernel:** Compile the Android kernel for specified devices.
- **Regenerate Defconfig:** Update kernel configuration based on specifications.
- **Open Menuconfig:** Customize kernel settings interactively.
- **Clean:** Remove generated files and start fresh.
- **Telegram Integration:** Send build status updates and logs to a Telegram channel or chat.

## Prerequisites

- `make`
- `curl`
- `bc`
- `zip`
- Clang and anykernel repositories cloned locally

## Usage

1. Clone this repository.
2. Ensure the required dependencies are installed.
3. Place this script within the Kernel Tree.
4. Grant execution permissions: `chmod 0777 origami_kernel_builder.sh`
5. Run the script: `bash origami_kernel_builder.sh`

## Configuration

- Modify the script variables (`ARCH`, `DEFCONFIG`, `localversion`, etc.) as per your kernel requirements.
- Set up Telegram integration by providing `chat_id` and `token` variables to enable messaging.

## How to Use

Upon running the script, it will prompt you with several options:

- **Build a whole Kernel:** Initiates the kernel compilation process.
- **Regenerate defconfig:** Updates kernel configuration.
- **Open menuconfig:** Customize kernel settings interactively.
- **Clean:** Removes generated files.
- **Quit:** Exit the script.

## Error Handling

The script handles various scenarios such as permission issues, missing dependencies, or configuration errors, providing relevant error messages and instructions for resolution.

## Contributions

Feel free to contribute to enhance features, improve error handling, or optimize the script's functionality.

## License

This script is licensed under the GNU General Public License v3.0. Refer to the [LICENSE](LICENSE) file for more details.

---

**Note:** Always review and modify the script variables and configurations as per your specific kernel building requirements before executing.
