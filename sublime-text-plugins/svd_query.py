import sublime
import sublime_plugin
import sqlite3
import os

# default database
sqlf = "/home/morris/Stuff/forth/svd2db-v2/svd2db.db"


def get_register(periph, reg):
    con = sqlite3.connect(sqlf)
    cur = con.cursor()

    cols = 'register, bitfield, name, address, bw, bo, description'

    query = f"SELECT {cols} FROM {periph} WHERE register LIKE '{reg}'"
    if reg != '%':
        query += f" ORDER BY name"

    ret = []
    res = cur.execute(query).fetchall()
    for x in res:
        if x[5] == 98:
            ret.append(f".equ {periph}_BASE, {x[3][0:7]}000\n")
            ret.append(f"  .equ _{x[2]}, 0x{x[3][7:]}\n")

        elif x[5] != 99:
            bf = f"{x[0]}_{x[1]}"
            if x[4] == 1:
                ret.append(f"    .equ b_{bf}, {x[4]}<<{x[5]}\n")
            else:
                mask = ((2**x[4] - 1) << x[5])
                ret.append(f"    .equ m_{bf}, 0x{mask:08X}\n")
                ret.append(f"    .equ o_{bf}, {x[5]}\n")

    con.close()
    return ret


def get_registers(periph):
    con = sqlite3.connect(sqlf)
    cur = con.cursor()
    query = f"select register, bo from {periph} WHERE bo = 98 ORDER BY register;"
    r = cur.execute(query).fetchall()
    con.close()
    res = []
    for i in r:
        res.append(i[0])
    return res


def get_peripherals():
    con = sqlite3.connect(sqlf)
    cur = con.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
    result = cur.fetchall()
    table_names = sorted(list(zip(*result))[0])
    con.close()
    return table_names


class SvdQueryCommand(sublime_plugin.TextCommand):
    def on_register_clicked(self, href):
        # Close the popup first
        self.view.hide_popup()
        index = int(href)
        selected_item = self.items[index]
        r = get_register(self.peripheral, selected_item)
        txt = ""
        for i in r:
            txt += i

        sublime.set_clipboard(txt)

    def on_item_clicked(self, href):
        # Close the popup first
        self.view.hide_popup()

        # href will be the index we passed in <a href="{idx}">
        index = int(href)
        selected_item = self.items[index]
        self.peripheral = selected_item
        self.items = get_registers(selected_item)

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

    # self.view.run_command("insert_command_output", {"cmd": ['lookup-svd', '-p', 'SPI0', '-r', 'SSpSR', '-a']})
    def run(self, edit):
        s = self.view.sel()

        # region = s[0]
        # if region.empty():
        #     word_region = self.view.word(region)
        #     print(self.view.substr(word_region))

        if len(s) == 2:
            periph = self.view.substr(s[0])
            reg = self.view.substr(s[1])
            pos = s[1].end()

        elif len(s) == 1 and s[0].begin() != s[0].end():
            periph = self.view.substr(s[0])
            reg = "%"
            pos = s[0].end()

        else:
            # Create HTML list of peripherals
            self.items = get_peripherals()
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

        pp = self.get_project_path()
        if pp:
            p = pp + "/svd2db.db"
            if os.path.isfile(p):
                sqlf = p
                sublime.status_message(f"SVD: Using database {sqlf}")

        r = get_register(periph.upper(), reg.upper())

        pos += self.view.insert(edit, pos, "\n")

        for x in r:
            pos += self.view.insert(edit, pos, x)

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
