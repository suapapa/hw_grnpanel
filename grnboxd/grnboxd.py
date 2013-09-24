#!/usr/bin/python

import serial
import statgrab
import time

def _reportCPU():
    cpuLoad = 100 - statgrab.sg_get_cpu_percents()['idle']
    return cpuLoad

def _reportMEM():
    memStat = statgrab.sg_get_mem_stats()
    memLoad = (memStat['used'] * 100) / memStat['total']
    return memLoad

def _sendMessage(ser, strMsg):
    ser.write("#M%s%s"%(chr(len(strMsg)), strMsg))
    time.sleep(0.1)

def _sendGuage(ser, value):
    ser.write("#G%s"%chr(int(value+0.5)&0xff))
    time.sleep(0.1)

if __name__ == '__main__':
    ser = serial.Serial('/dev/ttyUSB0', 9600)
    ser.write("#B%s"%chr(0xff/2))
    interval = 5
    print "Demon start"
    try:
        while(True):
            cpuLoad = _reportCPU()
            memLoad = _reportMEM()

            strReport = "CPU:%03d%% MEM:%03d%%"%(cpuLoad, memLoad)
            _sendMessage(ser, strReport)
            _sendGuage(ser, (cpuLoad*255)/100)
            
            time.sleep(interval)

    except Exception, e:
        print e 
        ser.close()

    print ('reporting terminated')
