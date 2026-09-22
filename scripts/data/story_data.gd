class_name StoryData
extends Resource

@export var title: String
@export var pages: Array[StoryPage] = []
@export_range(1.0, 200.0, 1.0) var characters_per_second: float = 42.0

