import sys
import sqlite3

newline_indent = '\n   '


def get_schema():
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
    result = cur.fetchall()

    table_names = sorted(list(zip(*result))[0])
    print("\ntables are:" + newline_indent + newline_indent.join(table_names))

    for table_name in table_names:
        result = cur.execute("PRAGMA table_info('%s')" % table_name).fetchall()
        column_names = list(zip(*result))[1]
        print(("\ncolumn names for %s:" % table_name) + newline_indent + (newline_indent.join(column_names)))


def get_table(t):
    # print('"peripheral", "register", "bitfield", "name", "address", "ar", "bw", "bo", "description"')
    print('"peripheral", "register", "bitfield", "name", "address", "bw", "bo"')
    cols = 'peripheral, register, bitfield, name, address, bw, bo'
    res = cur.execute(f"SELECT {cols} FROM {t}").fetchall()
    for x in res:
        print(x)


def get_peripherals():
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
    result = cur.fetchall()
    table_names = sorted(list(zip(*result))[0])
    print("\ntables are:" + newline_indent + newline_indent.join(table_names))


def get_register(periph, reg):
    cols = 'register, bitfield, name, address, bw, bo, description'

    query = f"SELECT {cols} FROM {periph} WHERE register LIKE '{reg}'"
    if reg != '%':
        query += f" ORDER BY name"

    res = cur.execute(query).fetchall()
    for x in res:
        if x[5] == 98:
            print("")
            print(f".equ {periph}_BASE, {x[3][0:7]}000")
            print(f"  .equ _{x[2]}, 0x{x[3][7:]}")
        elif x[5] != 99:
            bf = f"b_{x[0]}_{x[1]}"
            print(f"    .equ {bf}, {x[4]}<<{x[5]}")


if __name__ == "__main__":
    con = sqlite3.connect("svd2db.db")
    cur = con.cursor()

    if len(sys.argv) > 2:
        get_register(sys.argv[1].upper(), sys.argv[2].upper())

    elif len(sys.argv) > 1:
        periph = sys.argv[1].upper()
        if periph == 'SCHEMA':
            get_schema()

        elif periph == 'PERIPHERALS':
            get_peripherals()

        else:
            get_register(periph, "%")

    else:
        print("Usage: schema | peripherals | periphal [register]")
        # get_register("UART0", "%CR")
        # get_register("RESETS", "RESET")
        # get_register("UART0", "%CR")
        # get_table("UART0")

    con.close()
