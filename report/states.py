

# Defining these classes here so that pickling can work successfully
class States:
    pass

class StartEnd:
    def __init__(self, start_end):
        self.start = start_end[0]
        self.end = start_end[1]


if __name__ == "__main__":
    import sys
    mypath = sys.argv[1]
    from os import listdir
    from os.path import isfile, join
    onlyfiles = [f for f in listdir(mypath)]
    print("Files are:", onlyfiles)