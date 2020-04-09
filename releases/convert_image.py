from PIL import Image
import sys

im = Image.open("280resize.jpg")
(s,s,width,height)=im.getbbox()
count = 0
for y in range(height):
    for x in range(width):
        count = count+1
        pixel = im.getpixel((x,y))
        # AGBR ?
        sys.stdout.write('{:02X} '.format(pixel[0]))
        sys.stdout.write('{:02X} '.format(pixel[1]))
        sys.stdout.write('{:02X} '.format(pixel[2]))
        sys.stdout.write('{:02X} '.format(00))
        if (not (count % 4)):
            print('')
        #print(x,y,pixel)
        #21 10 0B 00
#print(list(im.getdata()))
