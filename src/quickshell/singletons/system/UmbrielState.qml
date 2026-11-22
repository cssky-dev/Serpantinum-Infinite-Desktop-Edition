pragma Singleton
import QtQuick

// The Umbriel compositor is not supported by this build; the workspaces bar face still refers to
// this state, so it exists as an inert singleton (no subscriptions, nothing occupied) instead of
// failing with "ReferenceError: UmbrielState is not defined".
QtObject {
    readonly property var occupiedByOutput: ({})

    function activeIndexFor(output) { return 0; }
    function countFor(output) { return 0; }
    function isOccupied(output, index) { return false; }
    function subscribe() {}
    function unsubscribe() {}
    function dispatch(command, args) {}
}
