local GuidanceConfig = {
	EnabledByDefault = true,
	RefreshSeconds = 0.25,
	MaxDistance = 1400,
	BeamColor = Color3.fromRGB(174, 96, 255),
	BeamColorLowDetail = Color3.fromRGB(138, 212, 255),
	BeamWidth0 = 0.45,
	BeamWidth1 = 0.18,
	LowDetailBeamWidth0 = 0.22,
	LowDetailBeamWidth1 = 0.1,
	TargetPartSize = Vector3.new(1.6, 1.6, 1.6),
	TargetHeightOffset = Vector3.new(0, 2.2, 0),
	LabelStudsOffset = Vector3.new(0, 2.7, 0),
	LabelMaxDistance = 180,
	ArrowPulseSeconds = 0.72,
}

return GuidanceConfig
