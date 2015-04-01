
from grovepi import *
from grove_rgb_lcd import setRGB, setText
import struct, sys, time, random, os

address = 0x04                  # arduino address
deflist = [254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254, 254]
bValue = 4250                   # analog temp parameter for GrovePi model 1.1
progress = False

os.putenv('TZ', 'America/New_York')

def dht_prep(pin=7, model=1):
    while True:
        try:
            #write_i2c_block(address, [40,pin,model,0])
            bus.write_i2c_block_data(address, 1, [40,pin,model,0])
            break
        except IOError:
            if progress:
                sys.stdout.write('-')
                sys.stdout.flush()
            time.sleep(0.6)
        continue
    if progress:
        sys.stdout.write('/')
        sys.stdout.flush()
    time.sleep(0.6)

    a = read_i2c_byte(address)
    if progress:
        sys.stdout.write('/')
        sys.stdout.flush()
    time.sleep(0.2)

    while True:
        try:
            #number = read_i2c_block(address)
            number = bus.read_i2c_block_data(address, 1)
            break
        except IOError:
            time.sleep(0.2)
            if progress:
                sys.stdout.write('.')
                sys.stdout.flush()
        continue
    if progress: print('>')
    return number

def dht_calc(number=deflist):
    f = 0
    # data is reversed
    for element in reversed(number[1:5]):
        # Converted to hex
        hex_val = hex(element)
        #print hex_val
        try:
            h_val = hex_val[2] + hex_val[3]
        except IndexError:
            h_val = '0' + hex_val[2]
        # Convert to char array
        if f == 0:
            h = h_val
            f = 1
        else:
            h = h + h_val
    # convert the temp back to float
    t = round(struct.unpack('!f', h.decode('hex'))[0], 2)

    h = ''
    # data is reversed
    for element in reversed(number[5:9]):
        # Converted to hex
        hex_val = hex(element)
        # Print hex_val
        try:
            h_val = hex_val[2] + hex_val[3]
        except IndexError:
            h_val = '0' + hex_val[2]
        # Convert to char array
        if f == 0:
            h = h_val
            f = 1
        else:
            h = h + h_val
    # convert back to float
    hum = round(struct.unpack('!f', h.decode('hex'))[0], 2)
    return [t, hum]


def analog_temp(pin=0):
    while True:
        try:
            bus.write_i2c_block_data(address, 1, [3, pin, 0, 0])
            break
        except:
            if progress:
                sys.stdout.write('.')
                sys.stdout.flush()
            time.sleep(0.3)

    time.sleep(0.3)
    bus.read_byte(address)
    time.sleep(0.3)
    while True:
        try:
            number = bus.read_i2c_block_data(address, 1)
            break
        except:
            if progress:
                sys.stdout.write(',')
                sys.stdout.flush()
            time.sleep(0.3)

    if progress: print('>')
    ar = number[1] * 256 + number[2]
    resistance = (float)(1023 - ar) * 10000 / ar
    t = (float)(1 / (math.log(resistance / 10000) / bValue + 1 / 298.15) - 273.15)
    return t

def data_to_rgb(dht_t=0, dht_h=0, t2=0):
    message = "T:%.1fF H:%.1f%%\nT2:%.1fF  %s" % (float(dht_t*9/5+32), float(dht_h), float(t2*9/5+32), time.strftime("%H:%M"))
    #print message
    setRGB(random.randint(0,255),random.randint(0,255),random.randint(0,255))
    setText(message)
    print message

while True:          # on occassion the DHT returns -10^38 for T and H
    time.sleep(0.2)
    n     = dht_prep(7,1)
    [t,h] = dht_calc(n)
    if t>0:
        break
t2    = analog_temp()
data_to_rgb(t,h,t2)
