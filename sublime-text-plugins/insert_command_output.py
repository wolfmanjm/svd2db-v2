import sublime
import sublime_plugin
import subprocess

"""
Run an external command and insert the output at the current cursor
Pass the commands as eg
self.view.run_command("insert_command_output", {"cmd": 'lookup-svd -p SPI0 -r SSpSR -a')
or it will prompt for a command
"""


class InsertCommandOutputCommand(sublime_plugin.TextCommand):
    def run(self, edit, **args):
        if 'cmd' in args:
            command = args['cmd']

            try:
                # Run the command and capture output
                output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
                output_text = output.decode("utf-8")
            except subprocess.CalledProcessError as e:
                sublime.status_message(f"Error: {e.output.decode('utf-8')}")
                return

            # Insert output at the first cursor/selection
            for region in self.view.sel():
                self.view.insert(edit, region.begin(), output_text)
                break  # Only insert once for first cursor

        else:
            # prompt for command
            self.view.window().show_input_panel("Enter shell command:", "", self.on_done, None, None)

    def on_done(self, command_str):
        if not command_str.strip():
            return
        if command_str.startswith('/'):
            pp = self.get_project_path()
            if pp:
                command_str = pp + command_str

        self.view.run_command("insert_command_output", {"cmd": command_str})

    def get_project_path(self):
        # Get the current file path
        file_path = self.view.file_name()
        if not file_path:
            sublime.status_message("No file to copy path from.")
            return None

        else:
            # Find the project root
            window = self.view.window()
            folders = window.folders()
            project_root = None
            for folder in folders:
                if file_path.startswith(folder):
                    project_root = folder
                    break

        if not project_root:
            sublime.status_message("File is not in any of the loaded projects.")
            return None

        # print(f"project root: {project_root}")
        return project_root
