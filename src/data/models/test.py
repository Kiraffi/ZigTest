
import json
from pprint import pprint
import struct

json_file = 'arrows.gltf'
cube = '1'

with open(json_file) as json_data:
    data = json.load(json_data)

#pprint(data)

#print "Dimension: ", data['cubes'][cube]['dim']
print("Generator:  ", data['asset']['generator'])
print("foo: ", data['asset'])

if 'generatora' in data['asset']:
    print("Has generator")
else:
    print("No generator")

print("A", " B", " C")

newFileBytes = [123, 3, 255, 0, 100]
print("Big:    ", struct.pack('>5B', *newFileBytes))
print("Little: ", struct.pack('<5B', *newFileBytes))
print("Native: ", struct.pack('@5B', *newFileBytes))
print(struct.pack('1i', 234234))
print("1f native", struct.pack('1f', 1))
print("1f big   ", struct.pack('>1f', 1))
print("1f little", struct.pack('<1f', 1))

foo = struct.pack('1f', 1);
print('1f first byte: ', foo[4])
#print(newFileBytes.to_bytes(5, byteorder='big'))


#print(struct.pack('5B'))
