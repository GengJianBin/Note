_author__="hyperchem"
import pykd
import sys
import os

def help():
    print ("autoDumpAnalyzer v0.1 by HyperChem")
    print ("autoDumpAnalyzer.py <dir> ;Analyze crashdump in dir")
def printDumpInfo(name):
    id=pykd.loadDump(name)
    print ("Exception IP:"+hex(pykd.getIP()))
    print ("Registers:")
    print (pykd.dbgCommand("r"))
    bcdata=pykd.bugCheckData()
    str_bcdata='BugCheck '
    for bb in bcdata:
        str_bcdata+=hex(bb)
        str_bcdata+=","
    print("BugCheckData:"+str_bcdata)
    pykd.closeDump(id)
def main():
    if len(sys.argv)!=2:
        help()
    else:
        dir=sys.argv[1]
        ll=len(dir)
        if dir[ll-1:]!="\\":
            dir+="\\"
        for dirpath,dirnames,filenames in os.walk(dir):
            for file in filenames:
                if ".dmp" in file.lower():
                    print("Analyzing CrashDump:"+file)
                    Fulldir=dir+file
                    printDumpInfo(Fulldir)
                    print("*************************************")
if __name__=='__main__':
   main()