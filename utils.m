classdef utils
    %UTILS
    %   工具类

    properties
    end

    methods
        function obj = utils()
            %UTILS 构造此类的实例
            %   此处显示详细说明
        end

    end

    methods (Static)

        %%%  SIGNAL PROCESSING UTILITIES  %%%

        function cstl = tocstl(varargin)
            % cstl = tocstl(x)
            % cstl = tocstl(ax, x)
            % cstl = tocstl(x, Name, Value)
            if nargin == 1
                ax = axes('FontName', "Times");
                x  = varargin{1};
            elseif nargin > 1
                ax = varargin{1};
                x  = varargin{2};
                nv = varargin(3:end);
            end
            box(ax, 'on');
            grid(ax, 'on');
            xlabel(ax, 'I');
            ylabel(ax, 'Q');
            hold(ax, 'on');
            if isreal(x)
                x = x + 0*1j;
            end
            ix = real(x);
            qx = imag(x);
            cstl = scatter(ax, ...
                ix, qx, ...
                'filled','o');
            names = nv(1:2:end);
            values = nv(2:2:end);
            assert(length(names) == length(values), '属性-值对输入错误');
            for k = 1:length(names)
                prop = names{k};
                value = values{k};
                set(cstl, prop, value);
            end
            xline(ax, 0, 'LineWidth', 2, 'Color', 'r');
            yline(ax, 0, 'LineWidth', 2, 'Color', 'r');

            l = max(abs([xlim(ax),ylim(ax)]));
            xlim(ax,[-l,l]);
            ylim(ax,[-l,l]);
            fig = ax.Parent;
            fig.Color = 'w';
        end

        %%%  IMAGE  PROCESSING UTILITIES  %%%

        function varargout = listdirim(varargin)
            % imname = listdirim(dirpath)
            if isempty(varargin)
                dirpath = '.';
                recursive = false;
            else
                dirpath = varargin{1};
                if endsWith(dirpath,'/')
                    dirpath = char(dirpath);
                    dirpath = dirpath(1:end-1);
                end
                if length(varargin) > 1
                    recursive = varargin{2};
                else
                    recursive = false;
                end
            end
            assert( ( ischar(dirpath) | ( isstring(dirpath) && isscalar(dirpath) ) ), ...
                'Directory path should be an array of char or a string.');
            listdir = struct2cell(dir(dirpath));
            fnames = listdir(1,3:end);
            isdirs = listdir(5,3:end);
            nfiles = length(fnames);
            supportedImgPostfix = {
                'png',
                'jpg',
                'jpeg',
                'pdf',
                'bmp'
                };
            imname = {}; % 初始化返回的cell数组

            for k = 1:nfiles
                currentFile = fnames{k};
                if isdirs{k} && recursive
                    folderpath = join({dirpath, currentFile},'/');
                    temp = utils.listdirim(folderpath{1});
                    if ~isempty(temp)
                        for m = 1:length(temp)
                            fname = temp{m};
                            fpath = join({folderpath{1}, fname}, '/');
                            imname{end+1} = fpath{1};
                        end
                    end
                end
                [~, ~, ext] = fileparts(currentFile); % 获取文件扩展名
                ext = strrep(ext, '.', ''); % 去掉扩展名中的点号

                % 检查是否是支持的扩展名之一
                if ismember(ext, supportedImgPostfix)
                    imname{end+1} = currentFile; % 添加到cell数组中
                end
            end
            imname = imname';
            varargout = cell(nargout);
            if isscalar(varargout)
                varargout{1} = imname;
            elseif isempty(varargout)
                s = sprintf('\t%s\n', imname{:});
                fprintf(['Image under directory [ %s ] --- \n' ...
                    '%s'], ...
                    dirpath, s);
            end
        end

        function batched = tobatch(x, rs, cs, varargin)
            % batched = tobatch(x, rs, cs, r, c, C)
            % rs: 每行拼接的图像数
            % cs: 每列拼接的图像数
            % r : 单一图像的行像素  - 默认: 96
            % c : 单一图像的列像素  - 默认: 96
            % C : 图像通道数       - 默认: 3

            % 解析输入参数，设置默认值或用户指定的参数
            if isempty(varargin)
                r = 96;
                c = 96;
                num_chan = 3;
            elseif isscalar(varargin)
                num_chan = varargin{1};
            elseif numel(varargin) == 3
                r = varargin{1};
                c = varargin{2};
                num_chan = varargin{3};
            end

            sz = size(x);

            % 如果输入是4维数组（批量图像），则逐张处理
            if numel(sz) == 4
                prev_batch = sz(1);
                batched = cell(prev_batch,1);
                for k = 1:prev_batch
                    sz_x = size(x,2,3,4);
                    xk = reshape(x(k,:,:,:), sz_x);
                    batched{k} = utils.tobatch(xk, rs, cs);
                end
                batched = cell2mat(batched);
            else
                % 初始化输出数组，用于存储切割后的批量图像
                batched = zeros(rs*cs,r,c,num_chan);

                % 按行切割图像
                for k = 1:rs
                    id0 = 1 + r*(k-1);
                    id1 = id0+(r-1);
                    idx = id0:id1;
                    row = x(idx,:,:);

                    % 在每行中按列切割图像
                    for m = 1:cs
                        img_id = (k-1)*cs + m;
                        id0 = 1 + c*(m-1);
                        id1 = id0+(c-1);
                        idx = id0:id1;
                        batched(img_id,:,:,:) = row(:,idx,:);
                    end
                end
            end
        end

        function grided = togrid(x, rs, cs)
            % grided = togrid(x, rs, cs)
            % x: 输入的批次图像，形状为 (Bs, height, width, channels)
            % rs: 每行放置的图像数
            % cs: 每列放置的图像数
            % grided: 拼接后的网格图像，形状为 (total_height, total_width, channels)

            % 获取输入图像的尺寸
            sz = size(x);
            B = sz(1);
            r = sz(2);
            c = sz(3);
            C = sz(4);

            % 检查每行和每列的图像数是否合理
            if rs * cs ~= B
                error('每行和每列的图像数乘积必须等于批次大小');
            end

            % 初始化网格图像
            h = r * cs;
            w = c * rs;
            grided = zeros(h, w, C);

            % 拼接图像
            for k = 1:cs
                for l = 1:rs
                    img_id = (k - 1) * rs + l;
                    idx0 = (k - 1) * r + 1;
                    idx1 = k * r;
                    idy0 = (l - 1) * c + 1;
                    idy1 = l * c;
                    grided(idx0:idx1, idy0:idy1, :) = x(img_id, :, :, :);
                end
            end
        end

        function grided = regrid(x, r, c, rs, cs)
            % new_grid = regrid(x, r, c, rs, cs)
            % r : 单个图像的行像素
            % c : 单个图像的列像素
            % rs: 新网格每行的图像数
            % cs: 新网格每列的图像数
            % grided: 新的网格图像

            % 获取输入网格的尺寸
            h = size(x, 1);
            w = size(x, 2);
            C = size(x, 3);

            % 计算原始网格的行数和列数
            or = h / r;
            oc = w / c;

            % 检查是否能整除
            if or ~= floor(or) || oc ~= floor(oc)
                error('输入网格尺寸与单个图像尺寸不匹配');
            end

            or = round(or);
            oc = round(oc);

            % 将网格转换为批次
            batched = utils.tobatch(x, or, oc, r, c, C);

            % 将批次重新组织成新网格
            grided = utils.togrid(batched, rs, cs);
        end

        function rebatched = rebatch(x, B, rs, cs, r, c)
            % rebatched = rebatch(x, B, rs, cs, r, c)
            % 将输入的batched或grided图像转换为新的batched图像，其中每个单一图像是一个grided图像
            % x: 输入的图像，可以是batched图像或grided图像
            % B: 新batched图像的批次大小
            % rs: 每个grided图像每行的图像数
            % cs: 每个grided图像每列的图像数
            % r: 每个grided图像中单个图像的行像素
            % c: 每个grided图像中单个图像的列像素
            % rebatched: 新的batched图像，其中每个单一图像是一个grided图像

            if ndims(x) == 4
                % 输入是batched图像
                sz = size(x);
                bs = sz(1);
                h = sz(2);
                w = sz(3);
                C = sz(4);

                % 判断是否是grided图像
                if mod(h, r) == 0 && mod(w, c) == 0
                    nr = h / r;
                    nc = w / c;
                    ts = nr * nc;
                    tb = bs * ts;
                    tb_img = zeros(tb, r, c, C);
                    for i = 1:bs
                        img = x(i, :, :, :);
                        sm_img = utils.tobatch(img, nr, nc, r, c, C);
                        tb_img(((i-1)*ts + 1):(i*ts), :, :, :) = sm_img;
                    end

                    gs = tb / B;
                    if gs ~= floor(gs)
                        error('批次大小不能整除');
                    end

                    rebatched = zeros(B, r * cs, c * rs, C);
                    for k = 1:B
                        s = (k - 1) * gs + 1;
                        e = k * gs;
                        rebatched(k, :, :, :) = utils.togrid(tb_img(s:e, :, :, :), rs, cs);
                    end
                else
                    error('batched图像中的单一图像尺寸与指定的r和c不匹配');
                end
            else
                % 输入是grided图像
                ors = size(x,1) / r;
                ocs = size(x,2) / c;
                batched = utils.tobatch(x, ors, ocs, r, c, size(x, 3));

                gs = size(batched, 1) / B;
                if gs ~= floor(gs)
                    error('批次大小不能整除');
                end

                rebatched = zeros(B, r * cs, c * rs, size(x, 3));
                for k = 1:B
                    s = (k - 1) * gs + 1;
                    e = k * gs;
                    rebatched(k, :, :, :) = utils.togrid(batched(s:e, :, :, :), rs, cs);
                end
            end
        end

        function xk = imgetk(x, k)
            % Shape: B,...
            sz = size(x);
            sz = sz(2:end);
            xk = reshape(x(k,:),sz);
        end

        function imshowk(x, k, varargin)
            % Shape: B,...
            im = utils.imgetk(x, k);
            if isempty(varargin)
                imshow(im);
            elseif isgraphics(varargin{1},'Axes')
                imshow(varargin{1}, im);
            end
        end

        function D = dct2(x,r,c,varargin)
            % Shape: (B),r,c,C

            % 判断图像通道数是否显式给出，如是灰度图，则必须显式给出
            if isempty(varargin)
                num_chan = 3;
            else
                num_chan = varargin{1};
            end
            sz = size(x);

            % 根据图像尺寸的维度（如果有四个维度，那么第一个维度是批次图像堆叠，该维度尺寸即批次大小
            if numel(sz) == 4
                num_batch = sz(1);

                % 返回D的大小为 B,r,c,C
                D = zeros(num_batch, r, c, num_chan);
                for k = 1:num_batch

                    % 如果是批次图像，那么对于批次中的每个图像，都执行一次本函数对于单一图像的处理
                    xk = utils.imgetk(x,k);

                    % 由于本函数处理单一图像的程序在(else)块中
                    % 所以对于批次图像，截取其中单一图像调用本函数处理即可
                    D(k,:,:,:) = utils.dct2(xk, r, c, num_chan);
                end
            else
                % 对于单一图像处理如下

                % 单一图像的DCT2，返回D的大小为 r,c,C
                D = zeros(r,c,num_chan);

                % 对于每个通道，均进行一次dct2（使用内置函数实现），并在C维度堆叠
                for chan = 1:num_chan

                    % 取出对应维度，并消除该维度（因为取出后该维度尺寸为1）
                    xchan = squeeze(x(:,:,chan));
                    D(:,:,chan) = dct2(xchan, r, c);
                end
            end
        end

        function x = idct2(D,r,c,varargin)
            % Shape: (B),r,c,C

            % 判断图像通道数是否显式给出，如是灰度图，则必须显式给出
            if isempty(varargin)
                num_chan = 3;
            else
                num_chan = varargin{1};
            end
            sz = size(D);

            % 根据图像尺寸的维度（如果有四个维度，那么第一个维度是批次图像堆叠，该维度尺寸即批次大小
            if numel(sz) == 4
                num_batch = sz(1);

                % 返回x的大小为 B,r,c,C
                x = zeros(num_batch, r, c, num_chan);
                for k = 1:num_batch

                    % 如果是批次图像，那么对于批次中的每个图像，都执行一次本函数对于单一图像的处理
                    Dk = utils.imgetk(D,k);

                    % 由于本函数处理单一图像的程序在(else)块中
                    % 所以对于批次图像，截取其中单一图像调用本函数处理即可
                    x(k,:,:,:) = utils.idct2(Dk, r, c, num_chan);
                end
            else
                % 对于单一图像处理如下

                % 单一图像的IDCT2，返回x的大小为 r,c,C
                x = zeros(r,c,num_chan);

                % 对于每个通道，均进行一次idct2（使用内置函数实现），并在C维度堆叠
                for chan = 1:num_chan

                    % 取出对应维度，并消除该维度（因为取出后该维度尺寸为1）
                    Dchan = squeeze(D(:,:,chan));
                    x(:,:,chan) = idct2(Dchan, r, c);
                end
            end
        end

    end
end

