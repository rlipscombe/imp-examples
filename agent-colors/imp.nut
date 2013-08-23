// Color Blink example for Hannah

class IoExpander
{
    i2cPort = null;
    i2cAddress = null;
    
    constructor(port, address)
    {
        if (port == I2C_12)
        {
            hardware.configure(I2C_12);
            i2cPort = hardware.i2c12;
        }
        else if (port == I2C_89)
        {
            hardware.configure(I2C_89);
            i2cPort = hardware.i2c89;
        }
        else
        {
            server.log("Invalid I2C port specified");
        }
        
        i2cAddress = address << 1;
    }
    
    // Read a byte
    function read(register)
    {
        local data = i2cPort.read(i2cAddress, format("%c", register), 1);
        if (data == null)
        {
            server.log("I2C read failure");
            return -1;
        }
        
        return data[0];
    }
    
    // Write a byte
    function write(register, data)
    {
        i2cPort.write(i2cAddress, format("%c%c", register, data));
    }

    // Write a bit to a register
    function writeBit(register, bitn, level)
    {
        local value = read(register);

        local mask = 1 << bitn;
        value = (level == 0) ? (value & ~mask) : (value | mask);
        
        write(register, value);
    }
    
    // Write a masked bit pattern
    function writeMasked(register, data, mask)
    {
        local value = read(register);
        value = (value & ~mask) | (data & mask);
        write(register, value);
    }
    
    function setPin(gpio, level)
    {
        local register = (gpio >= 8) ? 0x10 : 0x11;
        local bitn = gpio & 7;
        writeBit(register, bitn, level);
    }
    
    function setDir(gpio, output)
    {
        local register = (gpio >= 8) ? 0x0e : 0x0f;
        local bitn = gpio & 7;
        writeBit(register, bitn, output ? 0 : 1);
    }
    
    function setPullUp(gpio, enable)
    {
        local register = (gpio >= 8) ? 0x06 : 0x07;
        local bitn = gpio & 7;
        writeBit(register, bitn, enable);
    }
    
    // Set GPIO interrupt mask
    function setIrqMask(gpio, enable)
    {
        local register = (gpio >= 8) ? 0x12 : 0x13;
        local bitn = gpio & 7;
        writeBit(register, bitn, enable);
    }
    
    // Set GPIO edges
    function setIrqEdges(gpio, rising, falling)
    {
        local addr = 0x17 - (gpio >> 2);
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2 * falling + rising) << ((gpio & 3) << 1);
        writeMasked(add, data, mask);
    }
    
    function clearIrq(gpio)
    {
        local register = (gpio >= 8) ? 0x18 : 0x19;
        local bitn = gpio & 7;
        writeBit(register, bitn, 1);
    }
    
    function getPin(gpio)
    {
        local register = (gpio >= 8 ? 0x10 : 0x11) & (1 << (gpio & 7));
        return read(register) ? 1 : 0;
    }
}

class RgbLed extends IoExpander
{
    pinR = null;
    pinG = null;
    pinB = null;
    
    constructor(port, address, r, g, b)
    {
        base.constructor(port, address);
        
        pinR = r;
        pinG = g;
        pinB = b;
        
        // Disable pin input buffers.
        disablePinInputBuffer(pinR);
        disablePinInputBuffer(pinG);
        disablePinInputBuffer(pinB);
        
        // Set pins as outputs.
        setPinAsOutput(pinR);
        setPinAsOutput(pinG);
        setPinAsOutput(pinB);
        
        // Set pins open drain.
        setPinOpenDrain(pinR);
        setPinOpenDrain(pinG);
        setPinOpenDrain(pinB);
        
        // Enable LED drive.
        enableLedDrive(pinR);
        enableLedDrive(pinG);
        enableLedDrive(pinB);
        
        // Set to use internal 2MHz clock, linear fading.
        write(0x1e, 0x50);
        write(0x1f, 0x10);
        
        // Initialise as inactive.
        setLevels(0, 0, 0);
        setPin(pinR, 0);
        setPin(pinG, 0);
        setPin(pinB, 0);
    }

    function disablePinInputBuffer(pin)
    {
        writeBit(pin > 7 ? 0x00 : 0x01, pin > 7 ? (pin - 7) : pin, 1);
    }

    function setPinAsOutput(pin)
    {
        writeBit(pin > 7 ? 0x0E : 0x0F, pin > 7 ? (pin - 7) : pin, 0);
    }

    function setPinOpenDrain(pin)
    {
        writeBit(pin > 7 ? 0x0A : 0x0B, pin > 7 ? (pin - 7) : pin, 0);
    }
    
    function enableLedDrive(pin)
    {
        writeBit(pin > 7 ? 0x20 : 0x21, pin > 7 ? (pin - 7) : pin, 0);
    }
    
    function setLed(r, g, b)
    {
        if (r != null) writeBit(pinR>7?0x20:0x21, pinR & 7, r);
        if (g != null) writeBit(pinG>7?0x20:0x21, pinG & 7, r);
        if (b != null) writeBit(pinB>7?0x20:0x21, pinB & 7, r);
    }
    
    function setLevels(r, g, b)
    {
        if (r != null) write(pinR < 4?0x2A+pinR*3:0x36+(pinR-4)*5, r);
        if (g != null) write(pinG < 4?0x2A+pinG*3:0x36+(pinG-4)*5, g);
        if (b != null) write(pinB < 4?0x2A+pinB*3:0x36+(pinB-4)*5, b);
    }
}

led <- RgbLed(I2C_89, 0x3E, 7, 5, 6);

function change()
{
    // Schedule the next change.
    imp.wakeup(0.5, change);
    
    // Select a colour at random.
    local r = math.rand()%100;
    local g = math.rand()%100;
    local b = math.rand()%100;
    
    // Set the LED colour.
    led.setLevels(r, g, b);
}

imp.configure("Color Blink", [], []);

// Turn the LED on.
led.setLed(1, 1, 1);

//change();
led.setLevels(20, 20, 20);

agent.on("color", function(n) {
    server.log(n);
    if (n == "red") {
        led.setLevels(20, 0, 0);
    }
    else if (n == "green") {
        led.setLevels(0, 20, 0);
    }
    else if (n == "blue") {
        led.setLevels(0, 0, 20);
   }
});

