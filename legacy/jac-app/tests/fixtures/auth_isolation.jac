"""Isolated authentication fixture; not imported by the public demo."""

node Marker {
    has value: str = "";
}

walker:priv AddMarker {
    has value: str = "",
        reports: list[str] = [];

    can add with Root entry {
        root ++> Marker(value=self.value);
        report self.value;
    }
}

def:priv marker_values -> list[str] {
    return [marker.value for marker in [root-->][?:Marker]];
}
