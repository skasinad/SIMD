'''
Purpose of this is like a second opinion it should show its correct answers for any of the inputs

if both works then my design works well, if they disagree well then, its a bug...

just going to do the same thing implement all my instructions as their own function and just take the vectors as 
parameters 

can really only focus it on my arithmetic operations
'''

#elemnt wise implementations as well

#converting to int8
def convertINT8(num): 
    num = num & 0xFF
    if num >= 128: 
        num -= 256
    return num

def vadd(vec1, vec2):  
    result = []
    for i in range(8): 
        result.append(convertINT8(vec1[i]+vec2[i]))
    return result 

def vmul(vec1, vec2): 
    result = []
    for i in range(8): 
        result.append(convertINT8(vec1[i] * vec2[i]))
    return result 

def vmac(vec1, vec2, acc): 
    result = []
    for i in range(8): 
        result.append(convertINT8(acc[i] + (vec1[i] * vec2[i])))
    return result 

def vdot(vec1, vec2): 
    result = 0
    for i in range(8): 
        result += vec1[i] * vec2[i] #no clamping
    return result  


def vrelu(vec1):
    #a little different bc need to consider ignoring negative elements also
    result = []
    for elem in vec1: 
        if elem < 0: 
            result.append(0)
        else: 
            result.append(elem)
    return result 


#the"python" testbench(?)

#specifically left it this way bc i want to compare it to my testbench
vec1 = [1, 2, 3, 4, 5, 6, 7, 8]
vec2 = [2, 3, 4, 5, 6, 7, 8, 9]
vec3 = [-1, 2, -3, 4, -5, 6, -7, 8]
acc = [0, 0, 0, 0, 0, 0, 0, 0]

print("VADD instruction - ", vadd(vec1, vec2))
print("VMUL instruction - ", vmul(vec1, vec2))
print("VMAC instruction - ", vmac(vec1, vec2, acc))
print("VDOT instruction - ", vdot(vec1, vec2))
print("VRELU instruction - ", vrelu(vec3))