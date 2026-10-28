import sys
import os
import importlib.util

def LoadObject(name):
    p = os.path.abspath(name)
    if not p.endswith('.py'):
        p += '.py'
    spec = importlib.util.spec_from_file_location(os.path.basename(p)[:-3], p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
