'''
Purpose of this is like a second opinion it should show its correct answers for any of the inputs

if both works then my design works well, if they disagree well then, its a bug...

just going to do the same thing implement all my instructions as their own function and just take the vectors as 
parameters 

can really only focus it on my arithmetic operations
'''

def vadd(vec1, vec2):  
    return vec1 + vec2
def vmul(vec1, vec2): 
    return vec1 * vec2

def vmac(vec1, vec2, acc): 
    return acc + (vec1 * vec2) 

def vdot(vec1, vec2): 
    result = 0
    for i in range(8): #8bits
        total += vec1[i] * vec2[i]
    return result  


def vrelu(vec1): 
    pass