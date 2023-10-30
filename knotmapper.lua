-- takes a .txt file of a link from KP and generates a table containing the x coordinates of each bead.
-- mathematically, this is our filter function projecting to the first factor.
function filter_by_x(file)
    local xs = {}
    for line in io.lines(file) do 
        newline = line:gmatch("[^%s]*%d%s")() -- x coordinates in the file uniquely will have no leading spaces and will end with a decimal number and then a space
        xs[#xs + 1] = newline
    end
    return xs
end

-- I wonder what this function does
function max(t)
    local max = tonumber(t[1])
    for i = 2, #t do
        compare_val = tonumber(t[i])
        if max < compare_val then
            max = compare_val
        end
    end
    return max
end

-- mystery
function min(t)
    local min = tonumber(t[1])
    for i = 2, #t do
        compare_val = tonumber(t[i])
        if min > compare_val then
            min = compare_val
        end
    end
    return min
end

-- generates a table of cutpoints for a given number of bins with a given percent overlap.
-- the input table `t` should be a 1D table of coordinates; i.e., the output of the coordinate filter function.
function get_bins(t, num_bins, percent_overlap)
    bins = {}
    max = max(t)
    min = min(t)
    og_length = (max-min)/num_bins -- this is the bin size if there is zero percent overlap
    nudge = og_length*percent_overlap/(200-percent_overlap) -- nudge value is obtained by solving this equation: nudge = (1/2)(percent_overlap/100)(og_length + nudge) (the 1/2 comes from needing to nudge both endpoints)
    bins[0] = {min, og_length+nudge+min} -- endpoints don't get nudged
    bins[1] = {max-og_length-nudge, max}
    for j=1,num_bins-2 do -- rest of the endpoints
        left_end = j*og_length + min - nudge -- nudge left
        right_end = (j+1)*og_length + min + nudge -- nudge right
        bins[#bins+1] = {left_end, right_end} -- save
    end
    
    return bins
end

-- brute force intersection of two 1D tables.
function intersection(t1,t2)
    local res = {}
    for k1, v1 in pairs(t1) do -- go through all pairs
        for k2, v2 in pairs(t2) do
            if (t1[k1]==t2[k2]) then -- check if any pairs match
                res[#res + 1] = v1 -- congrats
            end
        end
    end
    return res
end

-- makes the vertices for the mapper graph. groups binned beads by connected components.
-- input file should be a .txt from knotplot after cutting according to some bin.
function make_vertices(file)
    local vertices = {}
    vertex_id, bead_id = 0 -- keeps track of vertices/connected components
    bead_id = 0 -- keeps track of beads within vertices/connected components
    vertices[vertex_id] = {} -- initialize the first vertex
    for line in io.lines(file) do 
        if line == "" then -- a blank line means we have left a connected component and need to create a new vertex
            vertex_id = vertex_id + 1
            bead_id = 0
            vertices[vertex_id] = {} -- initialize new vertex
            goto continue -- nothing more to do, go to the next line in the file
        end
        vertices[vertex_id][bead_id] = line -- put the current bead in the current vertex
        bead_id = bead_id + 1 -- increment bead counter
        ::continue::
    end
    return vertices
end

-- constructs the mapper graph. runs with n^2 complexity
-- TODO: optimize for the case where the filters are projections. no need to compare everything to everything in that case
-- n^2 complexity still needed for general filtering
function make_adj_list(vertices)
    adj_list = {}
    for vertex, beads in pairs(vertices) do
        adj_list[vertex] = {} -- initialize vertex as a table
        for vertex2, beads2 in pairs(vertices) do
            if vertex ~= vertex2 then -- loops will never exist; no need to store them
                if #intersection(vertices[vertex], vertices[vertex2]) > 0 then -- check for nonempty intersection
                    adj_list[vertex][vertex2] = 1 -- woot
                else
                    adj_list[vertex][vertex2] = 0 -- noot
                end
            end
        end
    end
    return adj_list
end

-- goes row by row through the lower triangle of an adjacency matrix and pads on the right with zeros until the length of the string is a multiple of 6.
-- `adj_list` should be a 2D table, where each "vertex" is a table that contains binary entries corresponding to adjacencies to other vertices.
-- I can phrase that better I guess. whatever the previous function makes such a list so it's ok
function get_amat_string(adj_list)
    res = ""
    n = #adj_list
    j = 0 -- the first entry is on the diagonal and not counted as a part of the lower triangle
    for k, v in pairs(adj_list) do
        for i = 1, j do
            res = res .. adj_list[k][i] -- do the thing
        end
        j = j + 1 -- the triangle grows
    end

    num_zero_pads = 6-(n*(n-1)/2 % 6) -- I did it the other way at first but trust me this is the right math
    for i = 1, num_zero_pads do
        res = res .. 0
    end

    return res
end

-- converts a decimal number to binary, and pads on the left with zeros until its length is either 18 or 36 (helper function for making the graph6 string)
local function convert_to_binary(decimal)
	local binary = ""
	while math.floor(tonumber(decimal)) > 0 do
		local num = decimal / 2
		decimal = math.floor(num)
		if num == decimal then
            binary = binary .. 0
        else
            binary = binary .. 1
        end
	end
    n = #binary

    num_zero_pads = 0

    if n > 18 then
        num_zero_pads = 36 - n
    else
        num_zero_pads = 18 - n
    end

    for i = 1, num_zero_pads do
        binary = binary .. 0
    end

	return string.reverse(binary)
end

-- another helper for the graph6 function. implements the R(x) function seen in the link.
function ascii_rep(amat)
    res = ""
    for str in amat:gmatch("......") do
        res = res .. string.char(tonumber(str, 2) + 63) -- interpret as binary
    end
    return res
end

-- see https://users.cecs.anu.edu.au/~bdm/data/formats.txt for more details on graph6
function graph6(vertices)
    n = #vertices
    order_info = ""
    if n < 2^6 then
        order_info = string.char(n + 63)
    elseif n < (2^12 * 63) then
        order_info = "~" .. ascii_rep(convert_to_binary(n))
    else
        order_info = "~~" .. ascii_rep(convert_to_binary(n))
    end
    amat = get_amat_string(make_adj_list(vertices))
    res = order_info .. ascii_rep(amat)
    return res
end

if #arg == 2 then

    num_bins = arg[1]
    percent_overlap = arg[2]

    executeKP([[
        save fullknot.txt
    ]])

    local knot = 'fullknot.txt'
    bins = get_bins(filter_by_x(knot), num_bins, percent_overlap)
    bin_num = 0
    for bin, endpoints in pairs(bins) do
        flag = 0
        for k, endpoint in pairs(endpoints) do
            endpoint = tonumber(endpoint)
            if flag == 0 then -- left endpoint
                com = "cut inside x " .. endpoint
                executeKP(com)
                flag = 1
            else -- right endpoint
                com = "cut outside x " .. endpoint
                executeKP(com)
                flag = 0
            end
        end
        filename = "bin" .. bin_num .. ".txt"
        com = "save " .. filename
        executeKP(com)
        bin_num = bin_num + 1
        executeKP([[load fullknot.txt]]) -- reload the knot so we can cut again
    end

    vertices = {}

    -- assemble the bins into one vertex table
    for j = 0, num_bins - 1 do
        bin_file = "bin" .. j .. ".txt"
        binverts = make_vertices(bin_file)
        for vertex, beads in pairs(binverts) do
            vertices[#vertices + 1] = beads
        end
        os.remove(bin_file) -- get rid of bins
    end

    os.remove("fullknot.txt") -- get rid of knot
    print("your graph6 string is: " .. graph6(vertices)) -- done!

else
    executeKP([[
        echo please specify a number of bins (first argument) and the percent overlap between adjacent bins (second argument)
    ]])
end