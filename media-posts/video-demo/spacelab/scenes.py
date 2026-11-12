#!/usr/bin/env python3
# Space Lab demo: one entry per camera shot on Stargazer (surface platform-8).
# cam = (x, y, zoom) the camera glides to; open = (entity name, recipe) whose window is shown
# while the scene holds (the instance nearest the camera); lines = narration, spoken in order.
SURFACE = "platform-8"
START = (0, 40, 0.4)

SCENES = [
    dict(cam=(0, 40, 0.4), lines=[
        "Welcome to the Space Lab demo.",
        "This is Stargazer, my research ship\non its way to the Shattered Planet.",
        "It produces all the resources it needs\nfrom asteroids.",
    ]),
    dict(cam=(0, -58, 0.6), lines=[
        "Collectors on the front edge\ncatch asteroid chunks.",
    ]),
    dict(cam=(-27, -46, 0.75), lines=[
        "Asteroids are processed separately by type,\nfor easier management.",
    ]),
    dict(cam=(35, -49, 0.75), open=("crusher", "bte-metallic-asteroid-crushing-stone-focused"), lines=[
        "Space Lab adds a new recipe that also\ngives stone from regular asteroids.",
    ]),
    dict(cam=(16, -49, 0.75), open=("crusher", "bte-shattered-synthesis"), lines=[
        "A new recipe, Shattered Synthesis,\ncrushes the red promethium chunks.",
        "It yields tungsten, holmium,\nand a new mineral: Flurolite.",
    ]),
    dict(cam=(-23, 110, 0.75), open=("cryogenic-plant", "bte-ammonia-extraction"), lines=[
        "Cryogenic plants make ammonia\nfrom stone, water and steam.",
    ]),
    dict(cam=(-22, 142, 0.8), open=("cryogenic-plant", "bte-lithium-focused-condensation"), lines=[
        "Flurolite is split into\nlithium brine and fluorine.",
    ]),
    dict(cam=(-53, 90, 0.55), lines=[
        "This is the Growth Facility,\nthe new building.",
        "It incubates eggs in orbit.",
    ]),
    dict(cam=(-53, 82, 0.8), open=("bte-growth-facility", "bte-biter-egg-incubation"), lines=[
        "One biter egg becomes nineteen,\nand they don't spoil inside.",
    ]),
    dict(cam=(-27, 126, 0.8), open=("bte-growth-facility", "bte-yumako-cultivation"), lines=[
        "It also grows Yumako\nand Jellynut from seeds.",
        "Biochambers turn them into nutrients.",
    ]),
    dict(cam=(-45, 122, 0.9), open=("biochamber", "agricultural-science-pack"), lines=[
        "Agricultural science\ncan now be made in space.",
    ]),
    dict(cam=(-31, 154, 0.8), open=("cryogenic-plant", "cryogenic-science-pack"), lines=[
        "Cryogenic science no longer needs\nAquilo's special conditions.",
    ]),
    dict(cam=(54, 162, 0.8), open=("electromagnetic-plant", "electromagnetic-science-pack"), lines=[
        "Electromagnetic science can also\nbe produced without limitations.",
    ]),
    dict(cam=(38, 140, 0.8), open=("foundry", "metallurgic-science-pack"), lines=[
        "Metallurgic science no longer\nneeds to be made on Vulcanus.",
    ]),
    dict(cam=(46, 114, 0.6), lines=[
        "These locally made packs\nfeed twenty-four labs.",
        "It's a complete science chain\nin deep space.",
    ]),
    dict(cam=(0, 70, 0.4), lines=[
        "That's Space Lab.\nThanks for watching!",
    ]),
]
