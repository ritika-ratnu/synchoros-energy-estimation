import sys
import argparse
import logging
from PowerCharacterizer import PowerCharacterizer

def run(args):
    ops = args.ops
    arch = args.arch
    power_characterizer = PowerCharacterizer()
    power_characterizer.run(ops, arch)

def main():
    parser = argparse.ArgumentParser()
    for arg in ("ops", "arch"):
        parser.add_argument(f"--{arg}", required=True)
    
    run(parser.parse_args())

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logging.exception("Fatal error")
        sys.exit(1)
