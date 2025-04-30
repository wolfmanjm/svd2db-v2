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

            # Replace this with your shell command
            # command = 'lookup-svd -p SPI0 -r SSpSR -a'

            try:
                # Run the command and capture output
                output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
                output_text = output.decode("utf-8")
            except subprocess.CalledProcessError as e:
                output_text = f"Error:\n{e.output.decode('utf-8')}"

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
        self.view.run_command("insert_command_output", {"cmd": command_str})
