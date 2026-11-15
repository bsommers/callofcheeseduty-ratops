"""blender -b -P tools/blender/world_sheet.py -- <sheetname> id1 id2 ... : contact sheet of out/previews/<id>.png"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from lib_common import *
a = sys.argv[sys.argv.index("--") + 1:]
contact_sheet(a[1:], os.path.join(PREVIEWS, a[0] + ".png"), cols=4)
