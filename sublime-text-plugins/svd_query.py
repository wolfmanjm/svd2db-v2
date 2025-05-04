import sublime
import sublime_plugin
import os
import subprocess


class SvdQueryCommand(sublime_plugin.TextCommand):
    def on_register_clicked(self, href):
        # Close the popup first
        self.view.hide_popup()
        index = int(href)
        selected_item = self.items[index]
        txt = self.get_register(self.peripheral, selected_item)

        sublime.set_clipboard(txt)
        self.view.run_command("paste")

    def on_item_clicked(self, href):
        # Close the popup first
        self.view.hide_popup()

        # href will be the index we passed in <a href="{idx}">
        index = int(href)
        selected_item = self.items[index]
        self.peripheral = selected_item
        self.items = self.get_registers(selected_item)
        if self.items is not None:
            # Create HTML list of registers
            html_content = f"Registers for {selected_item} <br><ul>"
            for idx, item in enumerate(self.items):
                html_content += f'<li><a href="{idx}">{item}</a></li>'
            html_content += "</ul>"

            # Show the popup
            self.view.show_popup(
                content=html_content,
                location=-1,
                max_width=800,
                max_height=800,
                on_navigate=self.on_register_clicked
            )
        return

    def get_peripherals(self):
        pl = self.run_command(f'{self.command} -l')
        if pl is not None:
            return pl[1:]
        else:
            sublime.status_message(f'{self.command} -l command failed: {pl}')
            return None

    def get_registers(self, periph):
        rl = self.run_command(f'{self.command} -p {periph} --regs')
        if rl is not None:
            return rl[1:]
        else:
            sublime.status_message(f'{self.command} -p {periph} --regs command failed: {rl}')
            return None

    def get_register(self, periph, reg):
        return self.run_command(f'{self.command} -p {periph} -r {reg} --asm', False)

    def run(self, edit):
        # we need to use the current directory so we can find the correct database file
        file_path = self.view.file_name()
        if file_path:
            directory = os.path.dirname(file_path)
            # sublime.message_dialog(f"Current directory: {directory}")
            self.command = f"lookup-svd -c {directory}"
        else:
            sublime.message_dialog("File must be saved to determine directory.")
            self.command = f"lookup-svd"

        s = self.view.sel()

        # region = s[0]
        # if region.empty():
        #     word_region = self.view.word(region)
        #     print(self.view.substr(word_region))

        if len(s) == 2:
            periph = self.view.substr(s[0])
            reg = self.view.substr(s[1])
            pos = s[1].end()

        # elif len(s) == 1 and s[0].begin() != s[0].end():
        #     periph = self.view.substr(s[0])
        #     reg = "%"
        #     pos = s[0].end()

        else:
            # Create HTML list of peripherals
            self.items = self.get_peripherals()
            if self.items is not None:
                html_content = "Peripherals<br><ul>"
                for idx, item in enumerate(self.items):
                    html_content += f'<li><a href="{idx}">{item}</a></li>'
                html_content += "</ul>"

                # Show the popup
                self.view.show_popup(
                    content=html_content,
                    location=-1,
                    max_width=300,
                    max_height=800,
                    on_navigate=self.on_item_clicked
                )
            return

        txt = self.get_register(periph, reg)
        if txt is not None:
            pos += self.view.insert(edit, pos, "\n")
            self.view.insert(edit, pos, txt)
        else:
            sublime.status_message("get_register failed")

    def run_command(self, cmd, as_list=True):
        try:
            # Run the command and capture output
            output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
            output_text = output.decode("utf-8")
        except subprocess.CalledProcessError as e:
            sublime.message_dialog(f"Error:\n{e.output.decode('utf-8')}")
            return None

        if as_list:
            # Convert output to a list
            return output_text.split('\n')
        else:
            return output_text

