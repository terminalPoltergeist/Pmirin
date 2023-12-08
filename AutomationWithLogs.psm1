<#
    .SYNOPSIS
        A stateful monad interface for automation scripts that handles logging
    .DESCRIPTION
        This module defines a structure for maintaining the state and history of an automation script for the duration of it's runtime.
        The exported module member is a single Initialize-Automation function.
        This function creates a globally scoped variable called $Automation. This variable is the API for the monad.
        An $Automation is instantiated with an $inputs object.
        An $Automation can then Invoke an Action. Actions are objects with a name and a script to run.
        Each $Automation.Invoke will update the $Automation.logs.
        Logs are objects that contain either a message or an exception.
    .EXAMPLE
        # functions can be passed as lambdas
        Initialize-Automation -inputs @{"name" = "World"; "message" = "Hello"}
        $Automation.Invoke({
            param([object]$inputs)
            return "$($inputs.message) $($inputs.name)"
        }) # calls the lambda on the $Automation's inputs
        $Automation.results # "Hello World"
        $Automation.logs # {"message": "Running lambda", "exception": null}
    .EXAMPLE
        # functions can be passed by name
        Initialize-Automation -inputs @{"name" = "World"; "message" = "Hello"}

        function greet {
            param([object]$inputs)
            return "$($inputs.message) $($inputs.name)"
        }

        $Automation.Invoke("greet")
        $Automation.results # "Hello World"
        $Automation.logs # {"message": "Running greet", "exception": null}
    .AUTHOR
        Jack Nemitz
#>

class log {
    [string]$msg = $null
    [object]$exception = $null

    log([string]$msg) {$this.msg=$msg}
    log([System.Exception]$exc) {$this.exception=$exc}

    [string] ToString() {
        if ($this.msg) {return $this.msg}
        else {return $this.exception}
    }
}

class action {
    [string]$name
    [scriptblock]$func

    action([string]$name) {
        $this.name = $name
        $this.func = (Get-Command $this.name).ScriptBlock
    }

    action([scriptblock]$func) {
        $this.name = "Lambda"
        $this.func = $func
    }

    action([string]$name, [scriptblock]$func) {
        $this.name = $name
        $this.func = $func
    }

    [object]Invoke([object]$inputs) {
        return ($this.func.Invoke($inputs))
    }
}

class automationWithLogs {
    [object]$inputs = $null
    [object]$results = $null # the output of running an action on some inputs
    hidden [action]$action = $null
    [boolean]$done = $false
    [log[]]$logs = @()

    automationWithLogs() {}
    automationWithLogs([pscustomobject]$inputs) {$this.inputs = $inputs}
    automationWithLogs([object]$inputs) {$this.inputs = $inputs}

    Invoke() {
        # if no input or action is provided, run the stored $Automation.action on $Automation.inputs
        $this.results = & ($this.action)($this.inputs)
        $this.logs = $this.logs + [log]::new("Running $($this.action.name)")
    }

    Invoke(
        [object]$action
    ) {
        # if an action is provided, run it on the stored $Action.inputs
        $this.action = [action]::new($action)
        $this.results = $this.action.Invoke($this.inputs)
        $this.logs = $this.logs + [log]::new("Running $($this.action.name)")
    }

    Invoke(
        [object]$inputs,
        [object]$action
    ) {
        # if an action and inputs are provided, run the action on the inputs
        $this.action = [action]::new($action)
        $this.results = & $action($inputs)
        $this.logs = $this.logs + [log]::new("Running $($this.action.name)")
    }

    [string] ToString() {
        $out = "Inputs:`n"
        $out += "`t$(($this.inputs.GetEnumerator().ForEach({ "$($_.Name): $($_.Value)" }) -Join "`n`t"))`n"
        $out += "Results:`n`t"
        $out += ($this.results)
        $out += "`nLogs:`n"
        $out += ($this.logs)
        return $out
    }
}

function Initialize-Automation {
    param (
        [object]$inputs
    )
    $auto = [automationWithLogs]::new($inputs)
    New-Variable -Name Automation -Value $auto -Scope global -Force
}

Export-ModuleMember -Function Initialize-Automation
