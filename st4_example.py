import sublime
import sublime_plugin

class ReplaceWordWithClickedItemCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        self.items = ["Hello", "World", "Foo", "Bar"]

        html_content = "<ul>"
        for idx, item in enumerate(self.items):
            html_content += f'<li><a href="{idx}">{item}</a></li>'
        html_content += "</ul>"

        self.view.show_popup(
            content=html_content,
            location=-1,
            max_width=300,
            max_height=200,
            on_navigate=self.on_item_clicked
        )

    def on_item_clicked(self, href):
        # Close the popup
        self.view.hide_popup()

        index = int(href)
        selected_item = self.items[index]

        # Begin an edit to modify the text
        self.view.run_command("replace_word_under_cursor", {"replacement": selected_item})

class ReplaceWordUnderCursorCommand(sublime_plugin.TextCommand):
    def run(self, edit, replacement):
        for region in self.view.sel():
            if region.empty():
                # No selection, so find the word under the cursor
                word_region = self.view.word(region)
            else:
                # If text is selected, replace the selection
                word_region = region

            self.view.replace(edit, word_region, replacement)
