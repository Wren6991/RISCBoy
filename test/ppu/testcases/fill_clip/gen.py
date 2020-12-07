for i in range(240):
    print("clip 0 319")
    print("fill r=31")
    print(f"clip {411 - 240 + i} {511 - 240 + i}")
    print("fill g=31")
    print(f"clip {319 - i} {i}")
    print("fill b=31")
    print("sync")
