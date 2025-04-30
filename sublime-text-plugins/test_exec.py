import sublime
import sublime_plugin
import subprocess

class InsertCommandOutputCommand(sublime_plugin.TextCommand):
    def run(self, edit, **args):
        command = args['cmd']

        # Replace this with your shell command
        #command = ['lookup-svd', '-p', 'SPI0', '-r', 'SSpSR', '-a']

        try:
            # Run the command and capture output
            output = subprocess.check_output(command, stderr=subprocess.STDOUT)
            output_text = output.decode("utf-8")
        except subprocess.CalledProcessError as e:
            output_text = f"Error:\n{e.output.decode('utf-8')}"

        # Insert output at the first cursor/selection
        for region in self.view.sel():
            self.view.insert(edit, region.begin(), output_text)
            break  # Only insert once for first cursor


