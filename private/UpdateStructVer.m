function UpdatedStruct = UpdateStructVer(OldVerStruct, NewVersionStruct,...
                                         shouldOverwrite)
    new_fields_names = fieldnames(NewVersionStruct);
    old_fields_names = fieldnames(OldVerStruct);
    % Add values that didn't exist before
    for n=1:length(new_fields_names)
        field_name = new_fields_names{n};
        if shouldOverwrite % Overwrite current value with new value
            OldVerStruct.(field_name) = NewVersionStruct.(field_name);
        % Write new value only if no value exists (i.e it's a new field)
        elseif ~any(strcmp(old_fields_names,field_name))
            OldVerStruct.(field_name) = NewVersionStruct.(field_name);
        end
    end
    % Remove values that no longer exists
    for n=1:length(old_fields_names)
        field_name = old_fields_names{n};
        if ~any(strcmp(new_fields_names,field_name))
            OldVerStruct = rmfield(OldVerStruct,field_name);
        end
    end
    UpdatedStruct = OldVerStruct;
end
