"""
meant to be copied and pasted into a micropython repl

the weird indentation is because micropython tries to be helpful with auto indenting.
"""
def padRelayData(data):
while((len(data)+6) % 16 != 0):
data += '\0'


    return data





def relayData(data):
relay.send(relay.BLUETOOTH, padRelayData(data))



